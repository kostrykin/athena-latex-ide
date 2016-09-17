using Gtk;
using Cairo;


public class PopplerRenderer
{

    public int first_page { public get; private set; default = 0; }
    public int  last_page { public get; private set; default = 0; }

    private double _scale;
    public  double  scale
    {
        get
        {
            lock( mutex )
            {
                return _scale;
            }
        }
        set
        {
            lock( mutex )
            {
                _scale = value;
                invalidate();
                wake_up();
            }
        }
    }

    private int mutex;
    private Thread< void* > render_thread;

    public struct Result
    {
        public int width  { public get; internal set; }
        public int height { public get; internal set; }

        Surface? rendering;

        internal void set( Result other )
        {
            this.width     = other.width;
            this.height    = other.height;
            this.rendering = other.rendering;
        }
    }

    private Poppler.Document document;
    private Result[] page_renderings;
    private bool[] finished_pages;

    public signal void started();
    public signal void finished();
    public signal void page_rendered( int page_idx );

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public PopplerRenderer( Poppler.Document document )
    {
        #if DEBUG
        ++_debug_instance_counter;
        #endif

        this.document = document;
        this.finished_pages  = new bool[ document.get_n_pages() ];
        this.page_renderings = new Result[ this.finished_pages.length ];
        for( int i = 0; i < this.page_renderings.length; ++i )
        {
            this.page_renderings[ i ] = Result();
        }
        invalidate();
    }

    ~PopplerRenderer()
    {
        #if DEBUG
        --_debug_instance_counter;
        #endif
    }

    public void fetch_result( int page_idx, ref Result result )
    {
        lock( mutex )
        {
            result.set( page_renderings[ page_idx ] );
        }
    }

    public void finish()
    {
        Thread< void* > render_thread;
        lock( mutex )
        {
            render_thread = this.render_thread;
        }
        if( render_thread != null )
        {
            render_thread.join();
        }
    }

    public void set_viewport( int first_page, int last_page )
    {
        lock( mutex )
        {
            this.first_page = first_page;
            this.last_page  = last_page;
            wake_up();
        }
    }

    private void wake_up()
    {
        lock( mutex )
        {
            if( render_thread == null )
            {
                render_thread = new Thread< void* >.try( "Poppler Render Thread", render_pages );
                started();
            }
        }
    }

    public void invalidate()
    {
        lock( mutex )
        {
            for( int page_idx = 0; page_idx < finished_pages.length; ++page_idx )
            {
                finished_pages[ page_idx ] = false;
            }
        }
    }

    public void get_page_size( int page_idx, out double width, out double height )
    {
        lock( mutex )
        {
            var page = document.get_page( page_idx );
            page.get_size( out width, out height );
        }
    }

    private void* render_pages()
    {
        bool  done = false;
        int[] pending_page_indices;
        int   pending_pages_count;

        pending_page_indices = new int[ document.get_n_pages() ];
        while( !done )
        {
            /* Determine the pages, which needs to be rendered.
             */
            pending_pages_count = 0;
            lock( mutex )
            {
                for( int page_idx = first_page; page_idx <= last_page; ++page_idx )
                {
                    if( !finished_pages[ page_idx ] )
                    {
                        pending_page_indices[ ++pending_pages_count - 1 ] = page_idx;
                    }
                }
            }

            /* Do the rendering.
             */
            for( int pending_page_idx = 0; pending_page_idx < pending_pages_count; ++pending_page_idx )
            {
                var scale = this.scale;
                var page_idx = pending_page_indices[ pending_page_idx ];
                Result result = Result();
                render_page( ref result, scale, page_idx );
                lock( mutex )
                {
                    page_renderings[ page_idx ].set( result );
                    finished_pages[ page_idx ] = ( scale == this.scale );

                    /* Schedule one-time call-back (return false).
                     */
                    Idle.add( () =>
                        {
                            page_rendered( page_idx );
                            return false;
                        }
                    );
                }
            }

            /* Check whether any visible pages have been invalidated.
             */
            lock( mutex )
            {
                if( !is_rendering_pending() )
                {
                    render_thread = null;
                    done = true;

                    /* Schedule one-time call-back (return false).
                     */
                    Idle.add( () =>
                        {
                            finished();
                            return false;
                        }
                    );
                }
            }
        }
        return null;
    }

    public bool is_rendering_pending()
    {
        lock( mutex )
        {
            for( int page_idx = first_page; page_idx <= last_page; ++page_idx )
            {
                if( !finished_pages[ page_idx ] )
                {
                    return true;
                }
            }
            return false;
        }
    }

    private void render_page( ref Result result, double scale, int page_idx )
    {
        double dw, dh;
        var page = document.get_page( page_idx );
        page.get_size( out dw, out dh );
        result.width  = (int)( scale * dw + 0.5 );
        result.height = (int)( scale * dh + 0.5 );

        var surface = new ImageSurface( Format.ARGB32, result.width, result.height );
        var context = new Context( surface );
        context.scale( scale, scale );
        page.render( context );
        result.rendering = context.get_target();
    }

}

