private static const int ASSISTANT_DOWNLOADABLE_PREREQUISITE_BUFFER_SIZE = 2 << 14; // 16 KiB

namespace Assistant
{

    public class DownloadablePrerequisite : AbstractPrerequisite
    {

        public string filename;
        public string url;
        public string download_dir;
        private Gee.Map< string, bool > search_dirs = new Gee.HashMap< string, bool >();
        private string  status_details = "";
        private bool downloaded = false;
        private string? error = null;

        public DownloadablePrerequisite( Context context, string filename, string url, string download_dir )
        {
            base( context );
            this.filename = filename;
            this.url = url;
            this.download_dir = download_dir;
            add_search_directory( download_dir, false );
        }

        public void add_search_directory( string path, bool recursive )
        {
            if( search_dirs[ path ] != true ) search_dirs[ path ] = recursive;
        }

        public void remove_search_directory( string path )
        {
            search_dirs.remove( path );
        }

        public void add_latex_package_search_directories()
        {
            add_search_directory( ".", false ); // search the project directory non-recursively
            add_search_directory( "/usr/share/texlive/texmf-dist/tex", true );
            add_search_directory( "/usr/share/texmf/tex/latex", true );
            add_search_directory( "~/texmf/tex/latex", true );
        }

        public void add_font_search_directories()
        {
            add_search_directory( "~/.fonts", true );
            add_search_directory( "/usr/local/share/fonts/truetype", true );
            add_search_directory( "/usr/share/fonts/truetype", true );
        }

        protected override Prerequisite.Status check_status()
        {
            if( filename.length == 0 )
            {
                warning( "Empty filename is prerequisite" );
                return Status.UNKNOWN;
            }
            if( search_dirs.size == 0 )
            {
                warning( "Filename without search directories is prerequisite" );
                return Status.UNKNOWN;
            }

            if( error != null ) set_status_details( error );
            else
            {
                if( !downloaded )
                {
                    foreach( var search_dir_path in search_dirs.keys )
                    {
                        bool recursive = search_dirs[ search_dir_path ];
                        string? file_path = search_directory( search_dir_path, recursive );
                        if( file_path != null )
                        {
                            set_status_details( "Found at %s".printf( file_path ) );
                            return Prerequisite.Status.FULFILLED;
                        }
                    }
                }
                else
                {
                    string? file_path = search_directory( download_dir, false );
                    if( file_path != null )
                    {
                        set_status_details( "Downloaded to %s".printf( file_path ) );
                        return Prerequisite.Status.FULFILLED;
                    }
                }
            }
            return Prerequisite.Status.VIOLATED;
        }

        private string? search_directory( string search_dir_path, bool recursive )
        {
            string abs_search_dir_path = context.resolve_path( search_dir_path );
            if( !FileUtils.test( abs_search_dir_path, FileTest.IS_DIR | FileTest.EXISTS ) ) return null;
            return Utils.find_file_by_exact_name( abs_search_dir_path, filename, recursive );
        }

        private void set_status_details( string status_details )
        {
            this.status_details = status_details;
            Idle.add( () =>
                {
                    status_details_changed();
                    return false;
                }
            );
        }
    
        public override string get_status_details()
        {
            return status_details;
        }

        protected override string get_default_name()
        {
            return filename;
        }
    
        public override bool is_fixable()
        {
            return filename.length > 0 && url.length > 0 && download_dir.length > 0;
        }
    
        public override async void fix() throws PrerequisiteError
        {
            base.fix();
            error = null;

            if( download_dir.length == 0 ) throw new PrerequisiteError.NOT_FIXABLE( "Unspecified download directory" );
            if(          url.length == 0 ) throw new PrerequisiteError.NOT_FIXABLE( "Unspecified download URL"       );

            /* Create download directory, where 493 is 755 in octal.
             */
            if( DirUtils.create_with_parents( context.resolve_path( download_dir ), 493 ) < 0 )
                throw new PrerequisiteError.NOT_FIXABLE( @"Can't create $download_dir" );

            SourceFunc callback = fix.callback;
            ThreadFunc< void* > run = () =>
            {
                try
                {
                    download();
                    downloaded = true;
                }
                catch( Error err )
                {
                    error = err.message;
                }
                invalidate_status();
                Idle.add( (owned) callback ); // catches up at latest occasion of the `yield` keyword
                return null;
            };
            Thread.create< void* >( run, false );

            yield; // pauses the execution of this method until `fix.callback` is called
        }

        /**
         * Downloads `url` to `download_dir/filename`.
         *
         * If `download_dir` is `.` or empty, then `context` is used to determine the project directory.
         */
        private void download() throws Error
        {
            set_status_details( "Downloading %s".printf( url ) );

            var session = new Soup.Session();
            var input   = session.request( url ).send();
            var path    = Path.build_path( Path.DIR_SEPARATOR_S, context.resolve_path( download_dir ), filename );
            var file    = File.new_for_path( path );
            var output  = file.replace( null, false, FileCreateFlags.NONE, null );

            ssize_t read;
            uint8 buffer[ ASSISTANT_DOWNLOADABLE_PREREQUISITE_BUFFER_SIZE ];
            while( ( read = input.read( buffer ) ) > 0 ) output.write( buffer[ 0 : read ] );
        }

    }

}

