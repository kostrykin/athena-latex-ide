namespace Assistant
{

    public class SummaryPage : Gtk.Grid, Page
    {

        public SummaryPage()
        {
            Object();

            column_spacing = 10;
               row_spacing = 10;
        }

        public bool is_complete()
        {
            return true;
        }

        public string get_name()
        {
            return "Summary";
        }

        private class LineInfo
        {
            public int line;
            public Gtk.Label label_view;
            public Gtk.Label value_view;
        }

        private int last_line = -1;
        private Gee.Map< string, LineInfo > lines = new Gee.HashMap< string, LineInfo >();

        public void set_line( string label, string value, string? line_id = null )
        {
            LineInfo? line_info = lines[ line_id ?? label ];
            if( line_info == null )
            {
                line_info = new LineInfo();
                line_info.line = ++last_line;
                line_info.label_view = new Gtk.Label( label );
                line_info.value_view = new Gtk.Label( value );
                line_info.label_view.show();
                line_info.value_view.show();
                line_info.label_view.set_alignment( 1, 0 );
                line_info.value_view.set_alignment( 0, 0 );
                line_info.label_view.get_style_context().add_class( "assistant-summary-label" );
                line_info.value_view.get_style_context().add_class( "assistant-summary-value" );
                line_info.value_view.ellipsize = Pango.EllipsizeMode.END;
                lines[ line_id ?? label ] = line_info;

                attach( line_info.label_view, 0, line_info.line, 1, 1 );
                attach( line_info.value_view, 1, line_info.line, 1, 1 );
            }
            else
            {
                line_info.label_view.set_text( label );
                line_info.value_view.set_text( value );
            }
        }

        public void prepare()
        {
        }

        public void set_assistant( AssistantWindow? assistant )
        {
        }

    }

}

