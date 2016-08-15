public class PopplerChoreographer
{

    private PopplerDisplay display;

    private enum AnimationType { ZOOM, PAN }
    private AnimationControl.Animation? current_animations[ 2 ];

    public PopplerChoreographer( PopplerDisplay display )
    {
        this.display = display;
    }

    /**
     * Starts the `animation` and ensures that only one animation from
     * the same `type` will be running at the same time.
     *
     * If another animation of the same `type` is already running, than
     * that other animation will be interrupted.
     */
    private void play( AnimationType type, AnimationControl.Animation animation, double duration )
    {
        if( current_animations[ type ] != null )
        {
            current_animations[ type ].kill();
        }
        animation.finished.connect( () => { current_animations[ type ] = null; } );
        current_animations[ type ] = animation;
        display.animations.start( animation, duration );
    }

    public void zoom_to( double dst_zoom )
    {
        var animation = new Animations.Interpol( { display.zoom }, { dst_zoom }, ( zoom ) =>
            {
                display.zoom = zoom[ 0 ];
            }
            , ( value ) => { return -Math.cos( ( 1 + value ) * Math.PI / 2 ); } // quick start, smooth landing
        );
        play( AnimationType.ZOOM, animation, 0.5 );
    }

    public void pan_to( double x, double y )
    {
        Utils.RectD visible_area = Utils.RectD.empty();
        display.fetch_visible_area( ref visible_area );
        var animation = new Animations.Interpol( { visible_area.cx, visible_area.cy }, { x, y }, ( center ) =>
            {
                display.set_visible_area( center[ 0 ], center[ 1 ] - display.visible_area_height / 2 );
            }
            , ( value ) => { return ( 1 - Math.cos( value * Math.PI ) ) / 2; } // smooth start, smooth landing
        );
        play( AnimationType.PAN, animation, 0.5 );
    }

}
