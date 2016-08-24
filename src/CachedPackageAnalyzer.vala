public class CachedPackageAnalyzer : Object
{

    private static Once< CachedPackageAnalyzer > _instance;
    public  static CachedPackageAnalyzer instance { get { return _instance.once( () => { return new CachedPackageAnalyzer( 20 ); } ); } }

    private PackageAnalyzer analyzer = new PackageAnalyzer();

    public int cached_packages_count { get; private set; }

    private Gee.Map< PackageAnalyzer.Request, PackageAnalyzer.Result > cached_results;
    private Gee.LinkedList< PackageAnalyzer.Request > order_of_access;

    private CachedPackageAnalyzer( int cached_packages_count )
    {
        this.cached_packages_count = cached_packages_count;

        cached_results = new Gee.HashMap< PackageAnalyzer.Request, PackageAnalyzer.Result >( PackageAnalyzer.Request.hash, PackageAnalyzer.Request.equal );
        order_of_access = new Gee.LinkedList< PackageAnalyzer.Request >( PackageAnalyzer.Request.equal );

        analyzer.done.connect( handle_done );
    }

    public void enqueue( PackageAnalyzer.Request request )
    {
        if( request in order_of_access )
        {
            order_of_access.remove( request );
            order_of_access.offer_head( request );
            request.done( cached_results[ request ] );
        }
        else analyzer.enqueue( request );
    }

    private void handle_done( PackageAnalyzer.Request request, PackageAnalyzer.Result package_info )
    {
        order_of_access.offer_head( request );
        while( order_of_access.size > cached_packages_count )
        {
            var old_request = order_of_access.poll_tail();
            cached_results.remove( old_request );
        }
        cached_results[ request ] = package_info;
    }

}

