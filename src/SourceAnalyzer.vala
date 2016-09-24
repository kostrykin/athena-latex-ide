public class SourceAnalyzer : Object
{

    private static Once< SourceAnalyzer > _instance;
    public  static SourceAnalyzer instance { get { return _instance.once( () => { return new SourceAnalyzer(); } ); } }

    private Regex        include_pattern;
    private Regex          input_pattern;
    private Regex   bibliography_pattern;
    private Regex          label_pattern;
    private Regex     usepackage_pattern;
    private Regex requirepackage_pattern;
    private Regex  documentclass_pattern;
    private Regex      bib_entry_pattern;
    private Regex     newcommand_pattern;

    /**
     * Creates a new pattern, which matches single-parameter commands, that are written on a single line.
     */
    private static Regex create_simple_command_pattern( string command ) throws RegexError
    {
        return new Regex( """[^%]*\\%s(?:\[[^\]]*\])?{([A-Za-z0-9_:]+)}""".printf( command ), RegexCompileFlags.ANCHORED );
    }

    private SourceAnalyzer()
    {
        string newcommand_instructions[] =
        {
            "newcommand",
            "renewcommand",
            "DeclareMathOperator",
            "DeclareMathSymbol",
            "DeclareRobustCommand",
            "def",
            "let"
        };
        try
        {
                   include_pattern = create_simple_command_pattern(        "include" );
                     input_pattern = create_simple_command_pattern(          "input" );
              bibliography_pattern = create_simple_command_pattern(   "bibliography" );
                     label_pattern = create_simple_command_pattern(          "label" );
             documentclass_pattern = create_simple_command_pattern(  "documentclass" );
                usepackage_pattern = create_simple_command_pattern(     "usepackage" );
            requirepackage_pattern = create_simple_command_pattern( "RequirePackage" );
             bib_entry_pattern = new Regex( """[^\\/]*@[a-z]{3,}{ *([A-Za-z0-9_:]+)""", RegexCompileFlags.ANCHORED );
            newcommand_pattern = new Regex( """[^%]*\\(?:%s){?\\([A-Za-z0-9_:]+)[}{\[]""".
                                            printf( string.joinv( "|", newcommand_instructions ) ), RegexCompileFlags.ANCHORED );
        }
        catch( RegexError err )
        {
            critical( err.message );
        }
    }

    /**
     * Indicates a reference path type.
     *
     *   - `UNKNOWN` means that the path could be either absolute or relative w.r.t. the build input file.
     *   - `ABSOLUTE` means that the path *is* an absolute path.
     *   - `SUB_REFERENCE` indicates that the path is relative w.r.t. that file, where it's encountered.
     */
    public enum FileReferenceType { UNKNOWN, ABSOLUTE, SUB_REFERENCE }

    public delegate void StringHandler( string value );
    public delegate void FileReferenceHandler( string path, FileReferenceType type );

    public void find_single_line_pattern( string source, StringHandler handle, Regex pattern )
    {
        foreach( var line in Utils.line_wise( source ) )
        {
            MatchInfo match;
            pattern.match( line, 0, out match );
            while( match.matches() )
            {
                handle( match.fetch( 1 ) );
                match.next();
            }
        }
    }

    public void find_labels( string source, StringHandler handle )
    {
        find_single_line_pattern( source, handle, label_pattern );
    }

    public void find_bib_entries( string source, StringHandler handle )
    {
        find_single_line_pattern( source, handle, bib_entry_pattern );
    }

    public void find_commands( string source, StringHandler handle )
    {
        find_single_line_pattern( source, handle, newcommand_pattern );
    }

    public void find_package_references( string source, StringHandler handle )
    {
        find_single_line_pattern( source, handle,     usepackage_pattern );
        find_single_line_pattern( source, handle,  documentclass_pattern );
        find_single_line_pattern( source, handle, requirepackage_pattern );
    }

    private static const string TEX_SUFFIX = ".tex";
    private static const string BIB_SUFFIX = ".bib";

    public void find_file_references( string source, FileReferenceHandler handle )
    {
        find_single_line_pattern( source, ( value ) => { handle( value + TEX_SUFFIX, FileReferenceType.UNKNOWN ); },        input_pattern );
        find_single_line_pattern( source, ( value ) => { handle( value + TEX_SUFFIX, FileReferenceType.UNKNOWN ); },      include_pattern );
        find_single_line_pattern( source, ( value ) => { handle( value + BIB_SUFFIX, FileReferenceType.UNKNOWN ); }, bibliography_pattern );
    }

}
