public class BuildManager
{

    public static const string COMMAND_PREVIEW = "preview";

    public static const string MODE_FULL  = "full";
    public static const string MODE_QUICK = "quick";

    public static const string VAR_INPUT     = "INPUT";
    public static const string VAR_OUTPUT    = "OUTPUT";
    public static const string VAR_BUILD_DIR = "BUILD_DIR";

    private Gee.Map< string, CommandSequence > build_types = new Gee.TreeMap< string, CommandSequence >();

    public BuildManager()
    {
        const string latex_cmds [] = { "pdflatex"     , "lualatex", "xetex" };
        const string build_names[] = { "Default LaTeX", "LuaLaTeX", "XeTeX" };
        for( int idx = 0; idx < latex_cmds.length; ++idx )
        {
            var latex_cmd = latex_cmds[ idx ];
            /*
             * The full build sequence looks as follows:
             *
             *  1. tex to pdf -- creates `.aux` file
             *  2. bibtex     -- creates `.ref` from `.aux` and `.bib` files
             *  3. tex to pdf -- creates citation entries from `.ref` file
             *  4. tex to pdf -- updates citations in text
             */
            build_types[ build_names[ idx ] ] = new CommandSequence.from_string(
                """
                mkdir -p "$BUILD_DIR"
                %s -output-directory "$BUILD_DIR" "$INPUT"
                %s: bibtex "$OUTPUT.aux"
                %s: $latex_cmd -output-directory "$BUILD_DIR" "$INPUT"
                %s: $latex_cmd -output-directory "$BUILD_DIR" "$INPUT"
                %s
                """.printf( latex_cmd, MODE_FULL, MODE_FULL, MODE_FULL, COMMAND_PREVIEW ) );
        }
    }

    public delegate void BuildTypeVisitor( string name, CommandSequence buildType );

    public void @foreach( BuildTypeVisitor func )
    {
        foreach( var e in build_types.entries )
        {
            func( e.key, e.value );
        }
    }

    public CommandSequence get( string name )
    {
        return build_types[ name ];
    }

    private string get_output( string input_path, string build_dir )
    {
        var basename = Path.get_basename( input_path );
        var n = basename.last_index_of_char( '.' );
        if( n == -1 )
        {
            n = basename.length;
        }
        return Path.build_path( Path.DIR_SEPARATOR_S, build_dir, n > -1 ? basename[ 0 : n ] : basename );
    }

    public CommandContext create_build_context( FileManager.File input )
        requires( !Path.get_basename( input.path ).has_prefix( "." ) ) // TODO: warn user that files starting with "." cannot be built
    {
        var  base_dir = Path.get_dirname( input.path );
        var build_dir = Path.build_path( Path.DIR_SEPARATOR_S, base_dir, ".build" + Path.DIR_SEPARATOR_S );
        var    output = get_output( input.path, build_dir );
        var   context = new CommandContext( base_dir );
        context.variables[     VAR_INPUT ] = input.path;
        context.variables[ VAR_BUILD_DIR ] = build_dir;
        context.variables[    VAR_OUTPUT ] = output;
        context.special_commands.add( COMMAND_PREVIEW );
        return context;
    }

}
