public class SourceAnalyzer : Object
{

    private static Once< SourceAnalyzer > _instance;
    public  static SourceAnalyzer instance { get { return _instance.once( () => { return new SourceAnalyzer(); } ); } }

    private Regex include_pattern;
    private Regex   input_pattern;
    private Regex   label_pattern;

    /**
     * Creates a new pattern, which matches single-parameter commands, that are written on a single line.
     */
    private static Regex create_simple_command_pattern( string command )
    {
        return new Regex( """[^%]*\\%s{([A-Za-z0-9_:]+)}""".printf( command ), RegexCompileFlags.ANCHORED );
    }

    private SourceAnalyzer()
    {
        include_pattern = create_simple_command_pattern(   "include" );
          input_pattern = create_simple_command_pattern(     "input" );
          label_pattern = create_simple_command_pattern(     "label" );
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
        // TODO: implement
    }

    private static const string TEX_SUFFIX = ".tex";

    public void find_file_references( string source, FileReferenceHandler handle )
    {
        find_single_line_pattern( source, ( value ) => { handle( value + TEX_SUFFIX, FileReferenceType.UNKNOWN ); },   input_pattern );
        find_single_line_pattern( source, ( value ) => { handle( value + TEX_SUFFIX, FileReferenceType.UNKNOWN ); }, include_pattern );
    }

}
