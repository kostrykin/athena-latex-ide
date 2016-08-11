public class BuildManager
{

    public static const string COMMAND_PREVIEW = "preview";
    public static const string MODE_FULL = "full";

    private Gee.Map< string, CommandSequence > build_types = new Gee.TreeMap< string, CommandSequence >();

    public BuildManager()
    {
        const string latex_cmds [] = { "pdflatex"     , "lualatex", "xetex" };
        const string build_names[] = { "Default LaTeX", "LuaLaTeX", "XeTeX" };
        for( int idx = 0; idx < latex_cmds.length; ++idx )
        {
            var latex_cmd = latex_cmds[ idx ];
            build_types[ build_names[ idx ] ] = new CommandSequence.from_string(
                """
                mkdir -p "$BUILD_DIR"
                %s -output-directory "$BUILD_DIR" "$INPUT"
                %s: bibtex "$OUTPUT.aux"
                %s: $latex_cmd -output-directory "$BUILD_DIR" "$INPUT"
                %s
                """.printf( latex_cmd, MODE_FULL, MODE_FULL, COMMAND_PREVIEW ) );
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
        context.variables[     "INPUT" ] = input.path;
        context.variables[ "BUILD_DIR" ] = build_dir;
        context.variables[    "OUTPUT" ] = output;
        context.special_commands.add( COMMAND_PREVIEW );
        return context;
    }

}
