public class Session
{

    /**
     * Indicates, that a file was modified by the user, since it was last saved or loaded.
     */
    public static uint FLAGS_MODIFIED = 1 << 0;

    /**
     * Indicates, that a file was changed by another user or program.
     */
    public static uint FLAGS_CONFLICT = 1 << 1;

    public SourceFileManager files { get; internal set; default = new SourceFileManager(); }

    private SourceFileManager.SourceFile? _master = null;
    public  SourceFileManager.SourceFile?  master
    {
        get { return _master; }
        set
        {
            if( _master != value )
            {
                var old = _master;
                _master = value;
                master_changed( old );
            }
        }
    }

    /**
     * Indicates, that the `master` property has really changed.
     *
     * This signal is *not* fired when `master` is updated with its current value.
     */
    public signal void master_changed( SourceFileManager.SourceFile? old );

    public string? output_path;

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public Session()
    {
        #if DEBUG
        ++_debug_instance_counter;
        #endif

        files.new_file_flags = FLAGS_MODIFIED;
    }

    #if DEBUG
    ~Session()
    {
        --_debug_instance_counter;
    }
    #endif

}
