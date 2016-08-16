public class SourceAnalyzer : Object
{

    private static Once< SourceAnalyzer > _instance;
    public  static SourceAnalyzer instance { get { return _instance.once( () => { return new SourceAnalyzer(); } ); } }

    private Regex label_pattern;

    private SourceAnalyzer()
    {
        label_pattern = new Regex( """\\label{([A-Za-z0-9_:]+)}""" );
    }

    public delegate bool StringHandler( string value );

    public void find_labels( string source, StringHandler handle )
    {
        MatchInfo match;
        label_pattern.match( source, 0, out match );
        while( match.matches() )
        {
            handle( match.fetch( 1 ) );
            match.next();
        }
    }

    public void find_bib_entries( string source, StringHandler handle )
    {
        // TODO: implement
    }

}
