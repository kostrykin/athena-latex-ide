namespace Assistant
{

    public interface Context : Object
    {
        public abstract string get_project_dir_path();

        public string resolve_path( string path )
        {
            var result = Utils.resolve_home_dir( path );
            if( result.length == 0 || !Path.is_absolute( result ) )
                result = Path.build_path( Path.DIR_SEPARATOR_S, get_project_dir_path(), result );
            return result;
        }

        public abstract void set_summary_line( string label, string value, string? line_id = null );
    }

    public interface Page : Gtk.Widget
    {
        public abstract void prepare();

        public signal void completed( Gtk.Widget page, bool complete );

        public abstract bool is_complete();

        public abstract string get_name();

        public abstract void set_assistant( AssistantWindow? assistant );
    }

    public class AssistantWindow : Gtk.Assistant, Context
    {

        private GeneralPage general_page { get; private set; }
        private SummaryPage summary_page { get; private set; default = new SummaryPage(); }

        public Gtk.Container navigation { get; private set; }

        public AssistantWindow( Gtk.Window? parent )
        {
            Object( use_header_bar: 1 );
            modal = true;
            set_transient_for( parent );
            set_default_size( 500, 500 );

            general_page = new GeneralPage( this );
            append_page  ( general_page );
            set_page_type( general_page, Gtk.AssistantPageType.INTRO );

            base.append_page ( summary_page );
            set_page_complete( summary_page, true );
            set_page_title   ( summary_page, summary_page.get_name() );
            set_page_type    ( summary_page, Gtk.AssistantPageType.CONFIRM );

            bool is_project_type_prepared = false;
            cancel.connect ( () => { destroy(); } );
            prepare.connect( () =>
                {
                    ( get_nth_page( get_current_page() ) as Page ).prepare();
                    if( get_current_page() == 1 )
                    {
                        general_page.sensitive = false;
                        if( !is_project_type_prepared )
                        {
                            is_project_type_prepared = true;
                            general_page.project_type.prepare( this );
                        }
                    }
                }
            );

            var tmp = new Gtk.Label( "" );
            add_action_widget( tmp );
            navigation = tmp.get_parent();
            navigation.remove( tmp );

            load_project_types();
        }

        public new int append_page( Page page )
        {
            var pos = Utils.max( 0, get_n_pages() - 1 );
            return insert_page( page, pos );
        }

        public new int insert_page( Page page, int position )
        {
            page.completed.connect( set_page_complete );
            page.set_assistant( this );
            page.hexpand = true;
            info( "Inserting page \"%s\" at position %d", page.get_name(), position );
            position = base.insert_page( page, position );
            set_page_title   ( page, page.   get_name() );
            set_page_complete( page, page.is_complete() );
            return position;
        }

        public new int prepend_page( Page page )
        {
            page.completed.connect( set_page_complete );
            page.set_assistant( null );
            return base.prepend_page( page );
        }

        private void load_project_types()
        {
            general_page.add_project_type( new Letter() );
            general_page.add_project_type( new JobApplication() );
            general_page.add_project_type( new MetropolisPresentation() );
        }

        public string get_project_dir_path()
        {
            return general_page.project_dir_path;
        }

        public void set_summary_line( string label, string value, string? line_id = null )
        {
            summary_page.set_line( label, value, line_id );
        }

    }

}

