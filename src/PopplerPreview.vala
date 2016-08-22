public class PopplerPreview : PdfPreview
{

    private static const double ZOOM_LEVEL_EPSILON = 0.1;
    private static const double ZOOM_STOPS[] = { 1.0 / 3, 1.0 / 2, 1, 1.5, 2, 2.5, 3, 4, 5 };

    private static Gtk.Image ICON_ZOOM_IN;
    private static Gtk.Image ICON_ZOOM_OUT;
    private static Gtk.Image ICON_ZOOM_ORIGINAL;
    private static Gtk.Image ICON_ZOOM_BEST_MATCH;

    static construct
    {
        ICON_ZOOM_IN         = new Gtk.Image.from_icon_name( "zoom-in-symbolic"      , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_ZOOM_OUT        = new Gtk.Image.from_icon_name( "zoom-out-symbolic"     , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_ZOOM_ORIGINAL   = new Gtk.Image.from_icon_name( "zoom-original-symbolic", MainWindow.TOOLBAR_ICON_SIZE );
        ICON_ZOOM_BEST_MATCH = new Gtk.Image.from_icon_name( "zoom-fit-best-symbolic", MainWindow.TOOLBAR_ICON_SIZE );
    }

    private PopplerDisplay display = new PopplerDisplay();
    private PopplerChoreographer choreographer;
    private Gtk.ToggleToolButton btn_zoom_best_match;
    private Gtk.Grid grid = new Gtk.Grid();
    private Gtk.Toolbar toolbar = new Gtk.Toolbar();
    private Gtk.Scale zoom;

    public PopplerPreview()
    {
        base( Gtk.Orientation.VERTICAL, 0 );
        choreographer = new PopplerChoreographer( display );

        grid.attach( display, 0, 0, 1, 1 );
        grid.attach( display.create_scrollbar( Gtk.Orientation.VERTICAL   ), 1, 0, 1, 1 );
        grid.attach( display.create_scrollbar( Gtk.Orientation.HORIZONTAL ), 0, 1, 1, 1 );
        grid.no_show_all = true;
 
        display.set( "expand", true );
        display.min_zoom = ZOOM_STOPS[ 0 ];
        display.max_zoom = ZOOM_STOPS[ ZOOM_STOPS.length - 1 ];
        display.zoom_changed.connect( () => { zoom.set_value( display.zoom ); } );

        display.add_events( Gdk.EventMask.BUTTON_PRESS_MASK );
        display.button_press_event.connect( ( event ) =>
            {
                if( event.type == Gdk.EventType.@2BUTTON_PRESS )
                {
                    int page_idx;
                    display.map_pixels_to_page_coordinates( ref event.x, ref event.y, out page_idx );
                    show_source_from_point( page_idx, event.x, event.y );
                    return true;
                }
                else
                {
                    return false;
                }
            }
        );

        zoom = new Gtk.Scale.with_range( Gtk.Orientation.HORIZONTAL, display.min_zoom, display.max_zoom, 0.1 );

        pack_end( grid, true, true );
        setup_toolbar();
   }

    public override void reload()
    {
        if( pdf_path != null )
        {
            grid.no_show_all = false;
            grid.show_all();
            grid.no_show_all = true;
        }
        else
        {
            grid.hide();
        }
        display.pdf_path = pdf_path;
    }

    private void setup_toolbar()
    {
        toolbar.set_icon_size( MainWindow.TOOLBAR_ICON_SIZE );

        btn_zoom_best_match = new Gtk.ToggleToolButton();
        btn_zoom_best_match.set_icon_widget( ICON_ZOOM_BEST_MATCH );
        btn_zoom_best_match.show();
        btn_zoom_best_match.set_active( true );
        btn_zoom_best_match.toggled.connect( () =>
            {
                if( btn_zoom_best_match.get_active() ) zoom_best_match();
                zoom.set_sensitive( !btn_zoom_best_match.get_active() );
            }
        );
        int my_current_width = -1;
        size_allocate.connect_after( ( alloc ) =>
            {
                if( my_current_width != alloc.width )
                {
                    if( btn_zoom_best_match.get_active() ) display.zoom = display.best_match_zoom_level;
                    my_current_width = alloc.width;
                }
            }
        );
        display.zoomed.connect( () => { btn_zoom_best_match.set_active( false ); } );
        toolbar.add( btn_zoom_best_match );

        var btn_zoom_original = new Gtk.ToolButton( ICON_ZOOM_ORIGINAL, null );
        toolbar.add( btn_zoom_original );
        toolbar.add( new Gtk.SeparatorToolItem() );
        btn_zoom_original.clicked.connect( zoom_original );
        btn_zoom_original.show();

        var btn_zoom_out = new Gtk.ToolButton( ICON_ZOOM_OUT, null );
        toolbar.add( btn_zoom_out );
        btn_zoom_out.clicked.connect( zoom_out );
        btn_zoom_out.show();

        var zoom_toolitem = new Gtk.ToolItem();
        zoom_toolitem.add( zoom );
        zoom_toolitem.set_expand( true );
        toolbar.add( zoom_toolitem );

        var btn_zoom_in = new Gtk.ToolButton( ICON_ZOOM_IN, null );
        toolbar.add( btn_zoom_in );
        btn_zoom_in.clicked.connect( zoom_in );
        btn_zoom_in.show();

        zoom.clear_marks();
        zoom.set_draw_value( false );
        zoom.set_has_origin( false );
        zoom.set_value( display.zoom );
        zoom.value_changed.connect( () =>
            {
                display.zoom = zoom.get_value();
            }
        );

        var busy_toolitem = new Gtk.ToolItem();
        var busy_view = new LoadingIndicator( MainWindow.TOOLBAR_ICON_SIZE );
        busy_toolitem.add( busy_view );
        busy_toolitem.show_all();
        toolbar.add( new Gtk.SeparatorToolItem() );
        toolbar.add( busy_toolitem );

        busy_view.fade_out( LoadingIndicator.FADE_IMMEDIATELY );
        display.renderer_started .connect( () => { busy_view.fade_in ( 5.0 ); } );
        display.renderer_finished.connect( () => { busy_view.fade_out( 1.0 ); } );

        toolbar.set_hexpand( true );
	pack_start( toolbar, false, false );
    }

    /**
     * Reduces the current zoom level to the next-lowest zoom stop.
     */
    public void zoom_out()
    {
        for( int i = ZOOM_STOPS.length - 1; i >= 0; --i )
        {
            if( ZOOM_STOPS[ i ] + ZOOM_LEVEL_EPSILON * ZOOM_STOPS[ i ] < display.zoom )
            {
                choreographer.zoom_to( ZOOM_STOPS[ i ] );
                break;
            }
        }
    }

    /**
     * Increases the current zoom level to the next-highest zoom stop.
     */
    public void zoom_in()
    {
        btn_zoom_best_match.set_active( false );
        for( int i = 0; i < ZOOM_STOPS.length; ++i )
        {
            if( ZOOM_STOPS[ i ] - ZOOM_LEVEL_EPSILON * ZOOM_STOPS[ i ] > display.zoom )
            {
                choreographer.zoom_to( ZOOM_STOPS[ i ] );
                break;
            }
        }
    }

    public void zoom_original()
    {
        btn_zoom_best_match.set_active( false );
        choreographer.zoom_to( 1 );
    }

    public void zoom_best_match()
    {
        if( !btn_zoom_best_match.get_active() ) btn_zoom_best_match.set_active( true );
        else choreographer.zoom_to( display.best_match_zoom_level );
    }

    public override void show_rect( int page, Utils.RectD page_rect )
    {
        Utils.RectD global_rect = new Utils.RectD.copy( page_rect );
        display.map_page_coordinates_to_global( page, ref global_rect.x, ref global_rect.y );

        var box = new Drawables.Box( global_rect, 1, 0.83, 0.37, 0.5, 0.8, 1 );
        var box_animation = new Animations.FadeOut( box );
        box_animation.finished.connect( () => { display.remove_drawable( box ); } );
        display.add_drawable( box );
        display.animations.start( box_animation, 3.5 );

        /* Check whether the `page_rect` is visible.
         * Change the viewport only if it isn't fully visible.
         */
        Utils.RectD visible_area = Utils.RectD.empty();
        display.fetch_visible_area( ref visible_area );
        if( global_rect.is_disjoint( visible_area ) )
        {
            /* Center view ontop of `global_rect`.
             */
            choreographer.pan_to( global_rect.cx, global_rect.cy );

            /* Adapt zoom level if necessary.
             * If adapting, then leave a small margin.
             */
            if( Athena.instance.settings.fit_preview_zoom_after_build && global_rect.w > display.visible_area_width )
            {
                btn_zoom_best_match.set_active( false );
                var suggested_zoom = display.zoom * visible_area.w / ( global_rect.w * 1.05 );
                choreographer.zoom_to( suggested_zoom );
            }
        }
    }

}
