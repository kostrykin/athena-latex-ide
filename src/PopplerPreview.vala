public class PopplerPreview : PdfPreview
{

    private Gee.List< double? > y_lookup = new Gee.ArrayList< double? >();
    private Gtk.Adjustment  v_adjustment = new Gtk.Adjustment( 0, 0, 0, 0, 0, 0 );
    private Gtk.Scrollbar    v_scrollbar;
    private PopplerRenderer     renderer;

    private double mid_page_height;

    private double _spacing = 0;
    public  double  spacing { set { _spacing = value; update_model(); } get { return _spacing; } }

    private double _zoom = 0.9;
    public  double  zoom
    {
        set
        {
            var adj = v_adjustment;
            var rel = ( adj.value + adj.page_size / 2 - adj.lower ) / ( adj.upper - adj.lower );
            _zoom = value;
            update_adjustments();
            adj.value = rel * ( adj.upper - adj.lower ) - adj.page_size / 2 + adj.lower;
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

    public PopplerPreview()
    {
        v_scrollbar = new Gtk.Scrollbar( Gtk.Orientation.VERTICAL, v_adjustment );
        v_adjustment.value_changed.connect( update_viewport );
    }

    public override void reload()
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
        }
        mid_page_height = page_heights.nth_data( page_heights.length() / 2 );
    }

    private void update_adjustments()
    {
        v_adjustment.page_size = mid_page_height / zoom;
        v_adjustment.upper = y_lookup[ y_lookup.size - 1 ] - v_adjustment.page_size;
        v_adjustment.page_increment = 1;
        v_adjustment.step_increment = 1;
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
        update_renderer_scale();
    }

    public override bool draw( Cairo.Context context )
    {
        var style = get_style_context();
        style.render_background( context, 0, 0, get_allocated_width(), get_allocated_height() );

        /* Draw pages [first...last] at `y_lookup` locations.
         */
        context.set_source_rgba( 1, 1, 1, 1 );
        var adj = v_adjustment;
        var scale = renderer.scale;
        for( int page_idx = renderer.first_page; page_idx <= renderer.last_page; ++page_idx )
        {
            var y = y_lookup[ page_idx ] - adj.value;
            var w = scale * pages[ page_idx ].width;
            var h = scale * pages[ page_idx ].height;
            var x = get_allocated_width() / 2 - w / 2;

	    context.rectangle( x, y, w, h );
	    context.fill();

            var rendering = renderer[ page_idx ];
            if( rendering != null )
            {
                context.set_source_surface( rendering, x, y );
                context.paint();
            }
        }

        return base.draw( context );
    }

}
