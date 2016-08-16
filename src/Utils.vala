public class Utils
{

    public static int min( int a, int b )
    {
        return a < b ? a : b;
    }

    public static int max( int a, int b )
    {
        return a > b ? a : b;
    }

    public static double mind( double a, double b )
    {
        return a < b ? a : b;
    }

    public static double maxd( double a, double b )
    {
        return a > b ? a : b;
    }

    public static bool same_files( string path1, string path2 )
    {
        var file1 = GLib.File.new_for_path( path1 );
        var file2 = GLib.File.new_for_path( path2 );
        if( file1.equal( file2 ) )
        {
            return true;
        }
        else
        {
            var info1 = file1.query_info( FileAttribute.ID_FILE, FileQueryInfoFlags.NONE );
            var info2 = file2.query_info( FileAttribute.ID_FILE, FileQueryInfoFlags.NONE );
            var id1 = info1.get_attribute_as_string( FileAttribute.ID_FILE );
            var id2 = info2.get_attribute_as_string( FileAttribute.ID_FILE );
            return id1 == id2;
        }
    }

    public struct RectD
    {
        public double x;
        public double y;
        public double w;
        public double h;

        public double r { get { return x + w; } set { w = value - x; } }
        public double b { get { return y + h; } set { h = value - y; } }

        public double cx { get { return x + w / 2; } }
        public double cy { get { return y + h / 2; } }

        public RectD( double x, double y, double w, double h )
        {
            this.x = x;
            this.y = y;
            this.w = w;
            this.h = h;
        }

        public RectD.copy( RectD other )
        {
            this.x = other.x;
            this.y = other.y;
            this.w = other.w;
            this.h = other.h;
        }

        public RectD.empty()
        {
        }

        public void make_joined_bounding_box( RectD other )
        {
            var this_r  = this.r;
            var this_b  = this.b;
            var other_r = other.r;
            var other_b = other.b;

            this.x = mind( x, other.x );
            this.y = mind( y, other.y );
            this.r = maxd( this_r, other_r );
            this.b = maxd( this_b, other_b );
        }

        public bool is_disjoint( RectD other )
        {
            /* Based on: http://gamedev.stackexchange.com/a/587/20553
             */
            return ( Math.fabs( cx - other.cx ) * 2 > ( w + other.w ) )
                || ( Math.fabs( cy - other.cy ) * 2 > ( h + other.h ) );            
        }
    }

    public static int count_char( string text, char c )
    {
        int count = 0;
        for( int i = 0; i < text.length; ++i ) if( text[ i ] == c ) ++count;
        return count;
    }

}
