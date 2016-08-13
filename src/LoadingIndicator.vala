using Cairo;


public class LoadingIndicator : Gtk.DrawingArea
{

    public static const double FADE_IMMEDIATELY = 0;

    private static const double RAD_PER_SECOND = 3.14;
    private static uint FPS = 25;

    private double rad = 0;
    private Surface icon;
    private int icon_width;
    private int icon_height;
    private double fade_level = 1;
    private double fade_level_change = 0;
    private double time0 = 0;

    public double opacity { get { return fade_level * fade_level; } }

    public LoadingIndicator( Gtk.IconSize icon_size, string icon_name = "process-working-symbolic" )
    {
        this.icon = Gtk.IconTheme.get_default().load_surface( icon_name, icon_size, 1, null, 0 );
        Gtk.icon_size_lookup( icon_size, out icon_width, out icon_height );
        set_size_request( icon_width, icon_height );

        update();
        Timeout.add( 1000 / FPS, update );
        draw.connect( do_draw );
    }

    private bool update()
    {
        var time = ( GLib.get_real_time() / 1000 ) * 1e-3;
        if( time0 > 0 )
        {
            var dt = Utils.maxd( 0, time - time0 );
            fade_level = Utils.maxd( 0, Utils.mind( 1, fade_level + dt * fade_level_change ) );
        }
        time0 = time;
        this.rad = ( time * RAD_PER_SECOND ) % ( 2 * Math.PI );
        queue_draw();
        return true;
    }

    public void fade_in( double per_second )
        requires( per_second >= 0 )
    {
        if( per_second == 0 )
        {
            fade_level = 1;
            fade_level_change = 0;
        }
        else
        {
            fade_level_change = per_second;
        }
    }

    public void fade_out( double per_second )
        requires( per_second >= 0 )
    {
        if( per_second == 0 )
        {
            fade_level = 0;
            fade_level_change = 0;
        }
        else
        {
            fade_level_change = -per_second;
        }
    }

    private bool do_draw( Cairo.Context cr )
    {
        var mid_x = get_allocated_width () / 2;
        var mid_y = get_allocated_height() / 2;
        cr.translate( mid_x, mid_y );
        cr.rotate( rad );
        cr.set_source_surface( icon, -icon_width / 2, -icon_height / 2 );
        cr.paint_with_alpha( opacity * opacity );
        return true;
    }

}
