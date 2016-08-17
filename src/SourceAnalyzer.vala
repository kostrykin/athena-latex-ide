public class SourceAnalyzer : Object
{

    private static Once< SourceAnalyzer > _instance;
    public  static SourceAnalyzer instance { get { return _instance.once( () => { return new SourceAnalyzer(); } ); } }

    private Regex label_pattern;

    private SourceAnalyzer()
    {
        label_pattern = new Regex( """[^%]*\\label{([A-Za-z0-9_:]+)}""", RegexCompileFlags.ANCHORED );
    }

    public delegate bool StringHandler( string value );

    public void find_labels( string source, StringHandler handle )
    {
        int start = 0;
        while( start + 1 < source.length )
        {
            int end = source.index_of_char( '\n', start );
            if( end == -1 ) end = source.length - 1;

            var line = source[ start : end ];
            MatchInfo match;
            label_pattern.match( line, 0, out match );
            while( match.matches() )
            {
                handle( match.fetch( 1 ) );
                match.next();
            }
            start = end + 1;
        }
    }

    public void find_bib_entries( string source, StringHandler handle )
    {
        // TODO: implement
    }

}
