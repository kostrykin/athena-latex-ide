public class SourceFileManager
{

    private static uint NEXT_NEW_FILE_INDEX = 1;

    private static uint BYTE_CODE_LF = 0x0A;

    public class SourceFile
    {
        private string? _path;
        private string? _contents;
        private File? file;
        private FileMonitor? monitor;

        public int    position { public get; internal set; }
        public uint   flags    { public get; internal set; }
        public string label    { public get;  private set; }
        public uint   hash     { public get; internal set; }

        /**
         * Indicates, that `file` was changed by this or another program.
         */
        public signal void changed( SourceFile file );

        public string? path
        {
            public get
            {
                return _path;
            }
            internal set
            {
                this._path = value;
                this.stop_monitor();
                if( value == null )
                {
                    uint new_file_index = NEXT_NEW_FILE_INDEX++;
                    this.label = "New File %u".printf( new_file_index );
                    this.file  = null;
                }
                else
                {
                    this.label   = Path.get_basename( this.path );
                    this.file    = File.new_for_path( this.path );
                    this.monitor = this.file.monitor( FileMonitorFlags.NONE, null );
                    if( _contents != null )
                    {
                        this.set_contents( _contents );
                        this._contents = null;
                    }
                }
            }
        }

        public string get_contents()
        {
            string contents;
            if( _contents != null )
            {
                contents = _contents;
            }
            else
            {
                if( path == null )
                {
                    contents = "";
                }
                else
                {
                    contents = Utils.read_text_file( file );
                }
            }
            hash = contents.hash();
            return contents;
        }

        public void set_contents( string contents )
        {
            hash = contents.hash();
            if( path == null )
            {
                _contents = contents;
            }
            else
            {
                string? owned_contents = null;
                unowned string encoded_contents = contents;

                /* If the contents end with an empty line, at least on Linux,
                 * we have to append another line feed at the end of the file,
                 * in order to preserve that line.
                 */
                if( contents.length > 0 && contents.data[ contents.data.length - 1 ] == BYTE_CODE_LF )
                {
                    owned_contents = contents + "\n";
                    encoded_contents = owned_contents;
                }
                file.replace_contents( encoded_contents.data, null, false, FileCreateFlags.NONE, null, null );
            }
        }

        public bool has_flags( uint flags )
        {
            return ( this.flags & flags ) != 0;
        }

        #if DEBUG
        public static uint _debug_instance_counter = 0;
        #endif

        internal SourceFile( string? path, int position, uint flags )
        {
            #if DEBUG
            ++_debug_instance_counter;
            #endif
    
            this.path     = path;
            this.position = position;
            this.flags    = flags;
        }

        ~SourceFile()
        {
            #if DEBUG
            --_debug_instance_counter;
            #endif
 
            stop_monitor();
        }

        internal void start_monitor( SourceFileManager manager )
        {
            if( this.monitor != null )
            {
                this.monitor.changed.connect( handle_monitor_changed );
            }
        }

        private void handle_monitor_changed( File file, File? other_file, FileMonitorEvent event_type )
        {
            changed( this );
        }

        internal void stop_monitor()
        {
            if( this.monitor != null )
            {
                this.monitor.changed.disconnect( handle_monitor_changed );
                this.monitor.cancel();
                this.monitor = null;
            }
        }
    }

    private Gee.LinkedList< SourceFile > files = new Gee.LinkedList< SourceFile >();
    private int named_files = 0;

    public uint     new_file_flags { get; set; default = 0; }
    public uint default_file_flags { get; set; default = 0; }

    private int get_insert_position_for_named( string path, int first, int last )
        ensures( result >= first )
        ensures( result <=  last )
    {
        if( last - first <= 1 )
        {
            if( path <= files[ first ].path )
            {
                return first;
            }
            else
            {
                return last;
            }
        }
        else
        {
            int mid = (first + last) / 2;
            if( path < files[ mid ].path )
            {
                return get_insert_position_for_named( path, first, mid );
            }
            else
            {
                return get_insert_position_for_named( path, mid, last );
            }
        }
    }

    public int find_position( string path )
        ensures( result >= -1 )
        ensures( result < files.size )
    {
        if( named_files == 0 )
        {
            return -1;
        }
        else
        {
            var position = get_insert_position_for_named( path, 0, named_files );
            return position < files.size && files[ position ].path == path ? position : -1;
        }
    }

    private int get_insert_position( string? path )
        ensures( result >= 0 )
        ensures( result <= files.size )
    {
        if( path == null )
        {
            return files.size;
        }
        else
        if( named_files == 0 )
        {
            return 0;
        }
        else
        {
            return get_insert_position_for_named( path, 0, named_files );
        }
    }

    public SourceFile open( string? path )
    {
        int position = get_insert_position( path );

        /* Assert that `path` isn't already open.
         */
        assert( position == files.size || files[ position ].path != path );

        var file = open_ex( path, position );
        return file;
    }

    /**
     * Closes the file at `position` and sets it position to `-1`.
     */
    public void close( int position )
        requires( position >= 0 )
        requires( position < files.size )
    {
        var file = files[ position ];
        remove_file( file );
        file.position = -1;
        invalidate( position, files.size - position + 1 );
    }

    private SourceFile open_ex( string? path, int position )
        requires( position >= 0 )
        requires( position <= files.size )
    {
        var flags = path == null ? new_file_flags : default_file_flags;
        var file  = new SourceFile( path, position, flags );
        insert_file( file );
        invalidate( position, files.size - position );
        return file;
    }

    /**
     * Enlists `file` without notifying anyone.
     *
     * This is an atomic, most low-level operation.
     * The `position` of the `file` is allowed to be *right after* the last element.
     */
    private void insert_file( SourceFile file )
        requires( file.position >= 0 )
        requires( file.position <= files.size )
    {
        if( file.path != null )
        {
            ++named_files;
        }
        for( int idx = file.position; idx < files.size; ++idx )
        {
            ++files[ idx ].position;
        }
        files.insert( file.position, file );
        file.start_monitor( this );
    }

    /**
     * Withdraws `file` without notifying anyone.
     *
     * This is an atomic, most low-level operation.
     */
    private void remove_file( SourceFile file )
        requires( file.position >= 0 )
        requires( file.position < files.size )
    {
        file.stop_monitor();
        files.remove_at( file.position );
        for( int idx = file.position; idx < files.size; ++idx )
        {
            --files[ idx ].position;
        }
        if( file.path != null )
        {
            --named_files;
        }
        if( files.size == named_files )
        {
            NEXT_NEW_FILE_INDEX = 1;
        }
    }

    public SourceFile get( int position )
        requires( position >= 0 )
        requires( position < files.size )
    {
        return files[ position ];
    }

    public void set_flags( int position, uint mask, bool on = true )
        requires( position >= 0 )
        requires( position < files.size )
    {
        if( on )
        {
            files[ position ].flags |= mask;
        }
        else
        {
            files[ position ].flags ^= mask & files[ position ].flags;
        }
        invalidate( position, 1 );
    }

    public SourceFile set_path( int position, string? path )
        requires( position >= 0 )
        requires( position < files.size )
    {
        var file = this[ position ];
        remove_file( file );
        file.path = path;
        file.position = get_insert_position( path );
        insert_file( file );
        int first_invalid = Utils.min( position, file.position );
        int  last_invalid = Utils.max( position, file.position );
        invalidate( first_invalid, last_invalid - first_invalid + 1 );
        return file;
    }

    private void invalidate( int first, int count )
        requires( first >= 0 )
        requires( first + count <= files.size + 1 )
    {
        invalidated( first, count );
    }

    public signal void invalidated( int first, int count );

    public int count
    {
        get
        {
            return files.size;
        }
    }

    public Gee.Iterator< SourceFile > iterator()
    {
        return files.iterator();
    }

    #if DEBUG
    public static uint _debug_instance_counter = 0;

    public SourceFileManager()
    {
        ++_debug_instance_counter;
    }

    ~SourceFileManager()
    {
        --_debug_instance_counter;
    }
    #endif

}
