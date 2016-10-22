public class BuildManager
{

    public static const string COMMAND_INIT    = "init-build";
    public static const string COMMAND_PREVIEW = "preview";

    public static const string MODE_FULL  = "full";
    public static const string MODE_QUICK = "quick";

    public static const string VAR_INPUT      = "INPUT";        ///< e.g. `/path/file.tex`
    public static const string VAR_INPUT_DIR  = "INPUT_DIR";    ///< e.g. `/path`
    public static const string VAR_INPUT_NAME = "INPUT_NAME";   ///< e.g. `file`
    public static const string VAR_OUTPUT     = "OUTPUT";       ///< e.g. `/path/.build/file
    public static const string VAR_BUILD_DIR  = "BUILD_DIR";    ///< e.g. `/path/.build`

    private Gee.Map< string, CommandSequence > build_types          = new Gee.TreeMap< string, CommandSequence >();
    private Gee.Map< uint  , string          > build_names_by_flags = new Gee.HashMap< uint  , string          >();

    public static const uint FLAGS_LUA_LATEX = ( 1 << 0 );
    public static const uint FLAGS_XE_LATEX  = ( 2 << 0 );
    public static const uint FLAGS_BIBTEX    = ( 3 << 0 );

    public BuildManager()
    {
        const string latex_cmds [] = { "pdflatex", "pdflatex"         , "lualatex"      , "lualatex"                     , "xelatex"      , "xelatex"                      };
        const bool   bibtex_on  [] = {  false    ,  true              ,  false          ,  true                          ,  false         ,  true                          };
        const string build_names[] = { "PdfLaTeX", "PdfLaTeX + BibTeX", "LuaLaTeX"      , "LuaLaTeX + BibTeX"            , "XeLaTeX"      , "XeLaTeX + BibTeX"             };
        const uint   flags      [] = {  0        ,  FLAGS_BIBTEX      ,  FLAGS_LUA_LATEX,  FLAGS_LUA_LATEX | FLAGS_BIBTEX,  FLAGS_XE_LATEX,  FLAGS_XE_LATEX | FLAGS_BIBTEX };
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
            build_names_by_flags[ flags[ idx ] ] = build_names[ idx ];
            build_types[ build_names[ idx ] ] = new CommandSequence.from_string(

                """
                %s
                %s: %s --output-directory "$BUILD_DIR" --interaction=batchmode --synctex=1 "$INPUT"
                %s: rm --force "$OUTPUT.bbl"
                %s: %s --output-directory "$BUILD_DIR" --interaction=batchmode "$INPUT"
                """
                .printf( COMMAND_INIT, MODE_QUICK, latex_cmd, MODE_FULL, MODE_FULL, latex_cmd )

                + ( bibtex_on[ idx ]
                ?
                    """
                    %s: bibtex -terse "$OUTPUT.aux"
                    %s: %s --output-directory "$BUILD_DIR" --interaction=batchmode "$INPUT"
                    """
                    .printf( MODE_FULL, MODE_FULL, latex_cmd )
                :
                    ""
                ) +

                """
                %s: %s --output-directory "$BUILD_DIR" --interaction=batchmode --synctex=1 "$INPUT"
                %s
                ln --force "$OUTPUT.pdf" "$INPUT_DIR/$INPUT_NAME.pdf"
                """
                .printf( MODE_FULL, latex_cmd, COMMAND_PREVIEW ) );
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

    private string get_input_name( string input_path )
    {
        var basename = Path.get_basename( input_path );
        var n = basename.last_index_of_char( '.' );
        if( n == -1 )
        {
            n = basename.length;
        }
        return n > -1 ? basename[ 0 : n ] : basename;
    }

    private string get_output( string input_name, string build_dir )
    {
        return Path.build_path( Path.DIR_SEPARATOR_S, build_dir, input_name );
    }

    public CommandContext create_build_context( SourceFileManager.SourceFile input )
        requires( !Path.get_basename( input.path ).has_prefix( "." ) ) // TODO: warn user that files starting with "." cannot be built
    {
        var  input_dir = Path.get_dirname( input.path );
        var  build_dir = Path.build_path( Path.DIR_SEPARATOR_S, input_dir, ".build" + Path.DIR_SEPARATOR_S );
        var input_name = get_input_name( input.path );
        var     output = get_output( input_name, build_dir );
        var    context = new CommandContext( input_dir );

        context.variables[      VAR_INPUT ] = input.path;
        context.variables[  VAR_INPUT_DIR ] = input_dir;
        context.variables[ VAR_INPUT_NAME ] = input_name;
        context.variables[  VAR_BUILD_DIR ] = build_dir;
        context.variables[     VAR_OUTPUT ] = output;

        context.special_commands.add( COMMAND_INIT    );
        context.special_commands.add( COMMAND_PREVIEW );
        return context;
    }

    private static uint compute_hemming_distance( uint f1, uint f2 )
    {
        uint distance = 0;
        for( int i = 0; i < 8 * (uint) sizeof( uint ); ++i )
        {
            uint mask = ( 1 << i );
            if( ( f1 & mask ) != ( f2 & mask ) ) ++distance;
        }
        return distance;
    }

    public string resolve_build_type( uint flags )
    {
        uint   min_error = 1 + 8 * (uint) sizeof( uint );
        string min_error_name = "";

        foreach( uint candidate_flags in build_names_by_flags.keys )
        {
            var candidate_distance = compute_hemming_distance( flags, candidate_flags );
            if( candidate_distance < min_error )
            {
                min_error = candidate_distance;
                min_error_name = build_names_by_flags[ candidate_flags ];
            }
        }

        if( min_error > 0 ) warning( "Failed to satisfy all requested build type flags (%u)", min_error );
        return min_error_name;
    }

}
