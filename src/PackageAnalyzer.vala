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

        public static uint hash( Request request )
        {
            Gee.HashDataFunc str_hash = Gee.Functions.get_hash_func_for( typeof( string ) );
            return str_hash( request.package_name );
        }

        public static bool equal( Request a, Request b )
        {
            return a.package_name == b.package_name && a.path == b.path;
        }
    }

    public signal void done( Request request, Result package_info );

    private int mutex;
    private Thread< void* > analyzer_thread;
    private Gee.Queue< Request > request_queue = new Gee.ArrayQueue< Request >();

    public class Result
    {
        public string name;
        public Gee.Collection< string > commands;
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
        if( analyzer_thread != null ) analyzer_thread.join();
    }

    public void enqueue( Request request )
    {
        bool restart;
        lock( mutex )
        {
            restart = analyzer_thread == null;
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

    private static int current_runs = 0;

    private void* analyze()
    {
        if( ++current_runs != 1 ) warning( "PackageAnalyzer.analyze started %d times", current_runs );
        Request? request;
        var cache = new Gee.HashMap< PackageAnalyzer.Request, PackageAnalyzer.Result >( PackageAnalyzer.Request.hash, PackageAnalyzer.Request.equal );
        while( ( request = poll_next_request() ) != null )
        {
            message( "Processing package \"%s\"", request.package_name );
            Result? package_info = cache[ request ];
            bool cache_hit = package_info != null;
            if( !cache_hit )
            {
                package_info = new Result();
                package_info.name = request.package_name;
                dispatch_request( package_info, request.path );
                cache[ request ] = package_info;
            }
            dispatch_package( package_info, request );
            if( !cache_hit ) Thread.usleep( (ulong) 1e5 );
        }
        lock( mutex )
        {
            analyzer_thread = null;
        }
        --current_runs;
        return null;
    }

    private void dispatch_package( Result package_info, Request request )
    {
        /* Schedule one-time call-back (return false).
         */
        Idle.add( () =>
            {
                done( request, package_info );
                request.done( package_info );
                return false;
            }
        );
    }

    private static Regex create_package_file_name_pattern( string package_name )
    {
        return new Regex( """%s\.(?:sty|cls|def)$""".printf( Regex.escape_string( package_name ) )
                        , RegexCompileFlags.ANCHORED | RegexCompileFlags.DOLLAR_ENDONLY );
    }

    public static string? find_package( string package_name, string? extra_path )
    {
        var filename_pattern = create_package_file_name_pattern( package_name );
        string? base_dir_paths[] = { extra_path, "/usr/share/texlive/texmf-dist/tex", "/usr/share/texmf/tex/latex" };
        string? file_path = null;

        for( int i = 0; file_path == null && i < base_dir_paths.length; ++i )
        {
            var base_dir_path = base_dir_paths[ i ];
            if( base_dir_path == null ) continue;
            file_path = Utils.find_file( base_dir_path, filename_pattern, i > 0 );
        }

        return file_path;
    }

    private static void dispatch_request( Result package_info, string? path )
    {
        var enqueued_package_names = new Gee.HashSet   < string >();
        var pending_package_names  = new Gee.ArrayQueue< string >();

        enqueued_package_names.add  ( package_info.name );
        pending_package_names .offer( package_info.name );

        package_info.commands = new Gee.HashSet< string >();
        while( !pending_package_names.is_empty )
        {
            var package_name = pending_package_names.poll();
            string? file_path = find_package( package_name, path );
            if( file_path == null ) warning( "Failed to find package \"%s\"", package_info.name );
            else
            {
                var file = File.new_for_path( file_path );
                var contents = Utils.read_text_file( file );
                SourceAnalyzer.instance.find_commands( contents, ( cmd ) => { package_info.commands.add( cmd ); } );
                SourceAnalyzer.instance.find_package_references( contents, ( used_package_name ) =>
                    {
                        if( used_package_name in enqueued_package_names ) return;
                        else
                        {
                            pending_package_names.offer( used_package_name );
                            enqueued_package_names.add ( used_package_name );
                        }
                    }
                );
            }
        }
    }

}

