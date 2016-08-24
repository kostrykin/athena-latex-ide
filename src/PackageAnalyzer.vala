public class PackageAnalyzer : Object
{

    public class Request
    {
        public string  package_name;
        public string? path;

        public Request( string package_name, string? path )
        {
            this.package_name = package_name;
            this.path = path;
        }

        public signal void done( Result package_info );
    }

    private int mutex;
    private Thread< void* > analyzer_thread;
    private Gee.Queue< Request > request_queue = new Gee.ArrayQueue< Request >();

    private static Once< PackageAnalyzer > _instance;
    public  static PackageAnalyzer instance { get { return _instance.once( () => { return new PackageAnalyzer(); } ); } }

    public class Result
    {
        public string name;
        public Gee.Collection< string > commands;
    }

    private PackageAnalyzer()
    {
    }

    ~PackageAnalyzer()
    {
        exit();
    }

    public void exit()
    {
        Thread< void* > analyzer_thread;
        lock( mutex )
        {
            analyzer_thread = this.analyzer_thread;
        }
        if( analyzer_thread != null )
        {
            analyzer_thread.join();
            this.analyzer_thread = null;
        }
    }

    public void enqueue( Request request )
    {
        bool restart;
        lock( mutex )
        {
            restart = request_queue.peek() == null;
            request_queue.offer( request );
        }
        if( restart )
        {
            exit();
            analyzer_thread = new Thread< void* >.try( "Package Analyzer Thread", analyze );
        }
    }

    private Request? poll_next_request()
    {
        lock( mutex )
        {
            return request_queue.poll();
        }
    }

    private void* analyze()
    {
        Request? request;
        while( ( request = poll_next_request() ) != null )
        {
            var package_info = new Result();
            package_info.name = request.package_name;
            dispose_request( package_info, request.path );
            dispose_package( package_info, request );
        }
        return null;
    }

    private static void dispose_package( Result package_info, Request request )
    {
        /* Schedule one-time call-back (return false).
         */
        Idle.add( () =>
            {
                request.done( package_info );
                return false;
            }
        );
    }

    private static Regex create_package_file_name_pattern( string package_name )
    {
        return new Regex( """%s\.(?:sty|cls)$""".printf( Regex.escape_string( package_name ) )
                        , RegexCompileFlags.ANCHORED | RegexCompileFlags.DOLLAR_ENDONLY );
    }

    private static void dispose_request( Result package_info, string? path )
    {
        var filename_pattern = create_package_file_name_pattern( package_info.name );
        string? file_path = null;
        string base_dir_paths[] = { path, "/usr/share/texlive/texmf-dist/tex" };

        for( int i = 0; file_path == null && i < base_dir_paths.length; ++i )
        {
            var base_dir_path = base_dir_paths[ i ];
            if( base_dir_path == null ) continue;
            file_path = Utils.find_file( base_dir_path, filename_pattern, i > 0 );
        }

        if( file_path == null ) warning( "Failed to find package \"%s\"", package_info.name );
        else
        {
            var file = File.new_for_path( file_path );
            var contents = Utils.read_text_file( file );
            package_info.commands = new Gee.HashSet< string >();
            SourceAnalyzer.instance.find_commands( contents, ( cmd ) => { package_info.commands.add( cmd ); } );
        }
    }

}

