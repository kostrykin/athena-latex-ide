namespace Utils
{

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

}
