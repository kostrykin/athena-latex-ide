public class PopplerDisplay : Gtk.Box
{

    private Gee.List< double? > y_lookup = new Gee.ArrayList< double? >();
    private Gtk.Adjustment  v_adjustment = new Gtk.Adjustment( 0, 0, 0, 0, 0, 0 );
    private Gtk.Adjustment  h_adjustment = new Gtk.Adjustment( 0, 0, 0, 0, 0, 0 );
    private Gtk.Scrollbar    v_scrollbar;
    private PopplerRenderer     renderer;

    private double max_page_width;
    private double mid_page_height;

    private double _spacing = 0;
    public  double  spacing { set { _spacing = value; update_model(); } get { return _spacing; } }

    private double _zoom = 1;
    public  double  zoom
    {
        set
        {
            var v_adj = v_adjustment;
            var h_adj = h_adjustment;
            var v_rel = ( v_adj.value + v_adj.page_size / 2 - v_adj.lower ) / ( v_adj.upper - v_adj.lower );
            var h_rel = ( h_adj.value + h_adj.page_size / 2 - h_adj.lower ) / ( h_adj.upper - h_adj.lower );
            _zoom = value;
            update_adjustments();
            v_adj.value = v_rel * ( v_adj.upper - v_adj.lower ) - v_adj.page_size / 2 + v_adj.lower;
            h_adj.value = h_rel * ( h_adj.upper - h_adj.lower ) - h_adj.page_size / 2 + h_adj.lower;
            update_renderer_scale();
        }
        get
        {
            return _zoom;
        }
    }

    public struct PageShape
    {
        public double width;
        public double height;
    }

    private PageShape[] pages;
    public int pages_count { get { return pages.length; } }

    private string? _pdf_path;
    public  string?  pdf_path { set { _pdf_path = value; reload(); } get { return _pdf_path; } }

    public PopplerDisplay()
    {
        v_adjustment.value_changed.connect( update_viewport );
        h_adjustment.value_changed.connect(      queue_draw );
    }

    public Gtk.Scrollbar create_scrollbar( Gtk.Orientation orientation )
    {
        switch( orientation )
        {

            case Gtk.Orientation.VERTICAL:
                return new Gtk.Scrollbar( orientation, v_adjustment );

            case Gtk.Orientation.HORIZONTAL:
                return new Gtk.Scrollbar( orientation, h_adjustment );

            default:
                assert_not_reached();

        }
    }

    public void reload()
    {
        if( this.renderer != null )
        {
            this.renderer.page_rendered.disconnect( handle_rendered_page );
            this.renderer.finish();
        }
        Poppler.Document document = new Poppler.Document.from_file( Filename.to_uri( pdf_path ), "" );
        pages = new PageShape[ document.get_n_pages() ];
        this.renderer = new PopplerRenderer( document );
        this.renderer.page_rendered.connect( handle_rendered_page );
        this.update_model();
        this.update_renderer_scale();
    }

    private void update_model()
    {
        this.analyze();
        this.update_adjustments();
    }

    private void analyze()
    {
        y_lookup.clear();
        double y = 0;
        List< double? > page_heights = new List< double? >();
        for( int page_idx = 0; page_idx < pages.length; ++page_idx )
        {
            PageShape* page = &pages[ page_idx ];
            renderer.get_page_size( page_idx, out page->width, out page->height );
            y_lookup.add( y );
            y += spacing + page->height;
            page_heights.insert_sorted_with_data( page->height, Gee.Functions.get_compare_func_for( typeof( double ) ) );
            max_page_width = page->width > max_page_width ? page->width : max_page_width;
        }
        mid_page_height = page_heights.nth_data( page_heights.length() / 2 );
    }

    private void update_adjustments()
    {
        v_adjustment.page_size = mid_page_height / zoom;
        v_adjustment.upper = y_lookup[ y_lookup.size - 1 ] + spacing + pages[ pages.length - 1 ].height;
        v_adjustment.page_increment = 1;
        v_adjustment.step_increment = 1;

        h_adjustment.page_size = get_allocated_width() * v_adjustment.page_size / get_allocated_height();
        h_adjustment.lower = Utils.mind( 0, ( h_adjustment.page_size - max_page_width ) / 2);
        h_adjustment.upper = Utils.maxd( 0, ( h_adjustment.page_size + max_page_width ) / 2);
        h_adjustment.page_increment = 1;
        h_adjustment.step_increment = 1;
    }

    public void fetch_viewport( out int first, out int last )
    {
        for( first = 0; first < pages_count; ++first )
        {
            if( first + 1 == pages_count || y_lookup[ first + 1 ] >= v_adjustment.value )
            {
                break;
            }
        }
        for( last = first; last < pages_count; ++last )
        {
            if( last + 1 == pages_count || y_lookup[ last + 1 ] >= v_adjustment.value + v_adjustment.page_size )
            {
                break;
            }
        }
    }

    private void update_viewport()
    {
        int first, last;
        fetch_viewport( out first, out last );
        renderer.set_viewport( first, last );
        this.queue_draw();
    }

    private void handle_rendered_page( int page_idx )
    {
        if( page_idx >= renderer.first_page && page_idx <= renderer.last_page )
        {
            this.queue_draw();
        }
    }

    private void update_renderer_scale()
    {
        renderer.scale = get_allocated_height() / v_adjustment.page_size;
        update_viewport();
    }

    public override void size_allocate( Gtk.Allocation allocation )
    {
        base.size_allocate( allocation );
        update_adjustments();
        update_renderer_scale();
    }

    public override bool draw( Cairo.Context context )
    {
        var style = get_style_context();
        style.render_background( context, 0, 0, get_allocated_width(), get_allocated_height() );

        /* Draw pages [first...last] at `y_lookup` locations.
         */
        context.set_source_rgba( 1, 1, 1, 1 );
        var scale = renderer.scale;
        PopplerRenderer.Result result;
        for( int page_idx = renderer.first_page; page_idx <= renderer.last_page; ++page_idx )
        {
            var y = get_allocated_height() * ( y_lookup[ page_idx ] - v_adjustment.value ) / v_adjustment.page_size;
            var w = scale * pages[ page_idx ].width;
            var h = scale * pages[ page_idx ].height;
            var x = ( get_allocated_width() - w ) / 2 - scale * h_adjustment.value;

	    context.rectangle( x, y, w, h );
	    context.fill();

            renderer.fetch_result( page_idx, out result );
            if( result.rendering != null )
            {
                var rendering_scale = w / result.width;
                context.translate( x, y );
                context.scale( rendering_scale, rendering_scale );
                context.set_source_surface( result.rendering, 0, 0 );
                context.paint();
                context.scale( 1 / rendering_scale, 1 / rendering_scale );
                context.translate( -x, -y );
            }
        }

        return base.draw( context );
    }

}
