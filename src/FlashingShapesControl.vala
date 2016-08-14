public class FlashingShapesControl
{

    public class Drawable
    {
        private Drawables.Shape shape;
        private double fade_level = 1;
        private double fade_level_change_per_second;

        internal Drawable( Drawables.Shape shape, double fade_level_change_per_second )
        {
            this.shape = shape;
            this.fade_level_change_per_second = fade_level_change_per_second;
        }

        internal bool update( double dt )
        {
            fade_level = fade_level + fade_level_change_per_second * dt;
            if( fade_level <= 0 )
            {
                fade_level = 0;
                return false;
            }
            return true;
        }

        public bool is_visible( Utils.RectD visible_rect )
        {
            return !shape.is_disjoint( visible_rect );
        }

        public void draw( Cairo.Context cr )
        {
            shape.draw( cr, Math.sqrt( fade_level ) );
        }
    }

    private Gee.List< Drawable > shapes = new Gee.LinkedList< Drawable >();
    private double time0 = -1;
    private uint fps;

    public FlashingShapesControl( uint fps )
    {
        this.fps = fps;
    }

    public void flash( Drawables.Shape shape, double duration )
    {
        shapes.insert( 0, new Drawable( shape, -1 / duration ) );
        if( time0 < 0 )
        {
            Timeout.add( 1000 / fps, update );
        }
    }

    private bool update()
    {
        var time = ( GLib.get_real_time() / 1000 ) * 1e-3;
        if( time0 > 0 )
        {
            var dt  = Utils.maxd( 0, time - time0 );
            Drawable?[] finished_shapes = new Drawable?[ shapes.size ];
            int finished_shapes_count = 0;
            foreach( var shape in shapes )
            {
                if( !shape.update( dt ) )
                {
                    finished_shapes[ finished_shapes_count++ ] = shape;
                }
            }
            for( var shape_idx = 0; shape_idx < finished_shapes_count; ++shape_idx )
            {
                shapes.remove_at( shape_idx );
            }
        }
        time0 = time;
        invalidated();
        if( shapes.size > 0 )
        {
            return true;
        }
        else
        {
            time0 = -1;
            return false;
        }
    }

    public Gee.Iterator< Drawable > iterator()
    {
        return shapes.iterator();
    }

    public uint count { get { return shapes.size; } }

    public signal void invalidated();

}

