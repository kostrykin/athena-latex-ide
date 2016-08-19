public abstract class PdfPreview : Gtk.Box
{

    private string? _pdf_path;
    public  string?  pdf_path { set { _pdf_path = value; reload(); reload_synctex(); } get { return _pdf_path; } }

    public abstract void reload();

    public abstract void show_rect( int page, Utils.RectD page_rect );

    private Synctex.Lib.Scanner scanner;

    public void reset_synctex()
        ensures( scanner == null )
    {
        scanner = null;
    }

    private void reload_synctex()
        ensures( ( pdf_path != null && scanner != null ) || ( pdf_path == null && scanner == null ) )
    {
        scanner = pdf_path != null ? new Synctex.Lib.Scanner( pdf_path, null ) : null;
    }

    public bool show_from_source( string source_file_path, int source_line )
        requires( scanner != null )
    {
        /* Since `source_file_path` might be an alias for the path actually
         * written by synctex, the first step is to determine the corresponding
         * path, if there is any.
         */
        Synctex.Lib.Node node = scanner.input();
        unowned string? real_file_path = null;
        while( node.valid )
        {
            real_file_path = scanner.get_name( node.tag );
            if( Utils.same_files( real_file_path, source_file_path ) )
            {
                /* The validity of `node` reflects our success.
                 */
                break;
            }
            else
            {
                node.sibling();
            }
            node.sibling();
        }

        /* We proceed, if the previous search was successful.
         * We only consider the results from the first matched page.
         *
         * SyncTeX counts code lines starting from 1 on.
         */
        if( node.valid && scanner.display_query( real_file_path, source_line + 1, 0 ) > 0 )
        {
            int page = -1;
            node = scanner.next_result();
            Utils.RectD? joined_rect = null;
            Utils.RectD tmp_rect = Utils.RectD( 0, 0, 0, 0 );
            while( node.valid )
            {
                if( page == -1 && node.page > -1 )
                {
                    page = node.page;
                }
                else
                if( page > -1 && page != node.page )
                {
                    continue;
                }

                tmp_rect.x = node.box_visible_h;
                tmp_rect.y = node.box_visible_v - node.box_visible_height;
                tmp_rect.w = node.box_visible_width;
                tmp_rect.h = node.box_visible_height + node.box_visible_depth;

                if( joined_rect == null )
                {
                    joined_rect = new Utils.RectD.copy( tmp_rect );
                }
                else
                {
                    joined_rect.make_joined_bounding_box( tmp_rect );
                }
                node = scanner.next_result();
            }

            if( page > -1 )
            {
                /* SyncTeX counts pages starting from 1 on.
                 */
                show_rect( page - 1, joined_rect );
                return true;
            }
        }

        return false;
    }

    public bool show_source_from_point( int page, double x, double y )
        requires( scanner != null )
    {
        /* SyncTeX counts pages starting from 1 on.
         */
        if( scanner.edit_query( page + 1, (float) x, (float) y ) > 0 )
        {
            var node = scanner.next_result();
            if( node.valid )
            {
                /* SyncTeX counts code lines starting from 1 on.
                 */
                string file_path = scanner.get_name( node.tag );
                source_requested( file_path, node.line - 1 );
                return true;
            }
        }

        return false;
    }

    public signal void source_requested( string source_file_path, int source_line );

}
