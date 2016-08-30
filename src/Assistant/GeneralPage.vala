namespace Assistant
{

    public class GeneralPage : Gtk.Grid, Page
    {

        private static const string PROJECT_TYPE_LABEL      = "Project Type:";
        private static const string PROJECT_DIRECTORY_LABEL = "Project Directory:";

        private weak AssistantWindow context;

        private Gtk.Entry     project_dir_entry          = new Gtk.Entry();
        private Gtk.Button    btn_browse_for_project_dir = new Gtk.Button.with_label( "Browse" );
        private Gtk.Label     project_type_details_view  = new Gtk.Label( "" );
        private Gtk.ListStore project_types              = new Gtk.ListStore( 2, typeof( string ), typeof( Object ) );
        private Gtk.TreeView  project_types_view;

        public GeneralPage( AssistantWindow context )
        {
            Object();
            this.context = context;
            this.context.set_summary_line( PROJECT_TYPE_LABEL, "" );

            column_spacing = 10;
               row_spacing = 10;

            var project_dir_label = new Gtk.Label( PROJECT_DIRECTORY_LABEL );

            btn_browse_for_project_dir.clicked.connect( browse_for_project_dir );
            project_dir_entry.changed.connect( handle_changed_project_dir );

            var project_types_name_renderer = new Gtk.CellRendererText();
            project_types_view = new Gtk.TreeView.with_model( project_types );
            project_types_view.vexpand = true;
            project_types_view.insert_column_with_attributes( -1, "Project Type", project_types_name_renderer, "text", 0 );
            project_types_view.cursor_changed.connect( handle_changed_project_type );

            project_type_details_view.wrap = true;
            project_type_details_view.wrap_mode = Pango.WrapMode.WORD;

            attach( project_dir_label         , 0, 0, 1, 1 );
            attach( project_dir_entry         , 1, 0, 1, 1 );
            attach( btn_browse_for_project_dir, 2, 0, 1, 1 );
            attach( project_types_view        , 0, 1, 3, 1 );
            attach( project_type_details_view , 0, 2, 3, 1 );
        }

        public void prepare()
        {
        }

        public string get_name()
        {
            return "General";
        }

        public void add_project_type( ProjectType project_type )
        {
            Gtk.TreeIter itr;
            project_types.append( out itr );
            project_types.set( itr, 0, project_type.get_name() );
            project_types.set( itr, 1, project_type            );
        }

        private void browse_for_project_dir()
        {
            FileDialog.choose_directory_and( get_toplevel() as Gtk.Window, project_dir_entry.set_text );
        }

        public string project_dir_path { get { return project_dir_entry.text; } }

        public bool is_complete()
        {
            return project_dir_path.length > 0 && Path.is_absolute( project_dir_path ) && project_type != null;
        }

        private void handle_changed_project_dir()
        {
            completed( this, is_complete() );
            context.set_summary_line( PROJECT_DIRECTORY_LABEL, project_dir_entry.text );
        }

        public ProjectType? project_type { get; private set; default = null; }

        private void handle_changed_project_type()
        {
            if( project_type != null ) project_type.withdraw( context );
            List< Gtk.TreePath > selected = project_types_view.get_selection().get_selected_rows( null );

            if( selected.length() > 0 )
            {
                Gtk.TreeIter iter;
                Value project_type_value;
                project_types.get_iter( out iter, selected.nth_data( 0 ) );
                project_types.get_value( iter, 1, out project_type_value );

                project_type = project_type_value.get_object() as ProjectType;
                project_type.activate( context );

                project_type_details_view.set_text( project_type.get_description() );
                project_type_details_view.visible = true;

                context.set_summary_line( PROJECT_TYPE_LABEL, project_type.get_name() );
            }
            else project_type_details_view.visible = false;

            completed( this, is_complete() );
        }

        public void set_assistant( AssistantWindow? assistant )
        {
        }

    }

}

