namespace Assistant
{

    public class PrerequisitesPage : Gtk.Box, Page
    {

        private static const string ICON_NAME_FULFILLED = "process-completed-symbolic";
        private static const string ICON_NAME_VIOLATED  = "process-error-symbolic";
        private static const string ICON_NAME_UNKNOWN   = "radio-symbolic";

        private static Gtk.IconSize ICON_SIZE = MainWindow.TOOLBAR_ICON_SIZE;

        private static const string STATUS_STACK_DEFAULT = "default";
        private static const string STATUS_STACK_BUSY    = "busy";

        private Gtk.Grid           contents         = new Gtk.Grid();
        private Gtk.ScrolledWindow contents_window  = new Gtk.ScrolledWindow( null, null );
        private Gtk.Button         btn_auto_fix     = new Gtk.Button.with_label( "Auto-fix Issues" );

        private string name;

        private bool _complete;
        private bool  complete { get { return _complete; } set { _complete = value; completed( this, value ); } }

        public PrerequisitesPage( string name = "Prerequisites" )
        {
            Object( orientation: Gtk.Orientation.VERTICAL, spacing: 10 );
            contents_window.add( contents );
            contents_window.get_vadjustment().changed.connect( scroll_to_bottom );
            contents.column_spacing = 10;
            contents.   row_spacing =  0;

            this.name = name;

            var buttons = new Gtk.ButtonBox( Gtk.Orientation.HORIZONTAL );
            buttons.pack_end( btn_auto_fix );
            buttons.hexpand = true;
            buttons.set_layout( Gtk.ButtonBoxStyle.END );

            pack_end( buttons        , false, false );
            pack_end( contents_window, true , true  );

            btn_auto_fix.clicked.connect( process_prerequisites );
            btn_auto_fix.no_show_all = true;

            complete = true;
            hexpand  = true;
        }

        private void scroll_to_bottom( Gtk.Adjustment vadj )
        {
            vadj.set_value( vadj.upper - vadj.page_size );
            vadj.value_changed();
        }

        public string get_name()
        {
            return name;
        }

        public bool is_complete()
        {
            return complete;
        }

        private class PrerequisiteInfo
        {
            public Gtk.Label name_view;
            public Gtk.Stack status_container;
            public Gtk.Image status_view;
            public Gtk.Label status_details_view;
            public LoadingIndicator busy_view;
            public bool is_violated = false;

            private int jobs_count = 0;

            public void increment_jobs( PrerequisitesPage page )
            {
                if( ++jobs_count == 1 )
                {
                    status_container.set_visible_child_name( STATUS_STACK_BUSY );
                    page.assistant.navigation.sensitive = false;
                    page.btn_auto_fix.sensitive = false;
                    update_auto_fix_button( page );
                }
            }

            public void decrement_jobs( PrerequisitesPage page )
            {
                if( --jobs_count == 0 )
                {
                    status_container.set_visible_child_name( STATUS_STACK_DEFAULT );
                    page.assistant.navigation.sensitive = true;
                    page.btn_auto_fix.sensitive = true;
                    update_auto_fix_button( page );
                }
            }

            private void update_auto_fix_button( PrerequisitesPage page )
            {
                page.btn_auto_fix.sensitive = false;
                page.btn_auto_fix.visible   = false;
                foreach( var prerequisite in page.prerequisites )
                {
                    var info = page.prerequisite_infos[ prerequisite ];
                    if( info.is_violated )
                    {
                        page.btn_auto_fix.visible = true;
                        if( jobs_count > 0 ) break;
                        if( prerequisite.is_fixable() )
                        {
                            page.btn_auto_fix.sensitive = true;
                            break;
                        }
                    }
                }
            }
        }

        private Gee.List< Prerequisite > prerequisites = new Gee.ArrayList< Prerequisite >();
        private Gee.Map< Prerequisite, PrerequisiteInfo > prerequisite_infos = new Gee.HashMap< Prerequisite, PrerequisiteInfo >();

        public void add_prerequisite( Prerequisite prerequisite )
            requires( !( prerequisite in prerequisite_infos.keys ) )
        {
            prerequisites.add( prerequisite );
            int last_prerequisite_index = prerequisites.size - 1;

            var info = new PrerequisiteInfo();
            prerequisite_infos[ prerequisite ] = info;

            info.name_view = new Gtk.Label( prerequisite.get_name() );
            info.name_view.get_style_context().add_class( "assistant-prerequisite-name" );
            info.name_view.hexpand = true;
            info.name_view.set_alignment( 0, 0.5f );
            info.status_container = new Gtk.Stack();
            info.status_view = new Gtk.Image();
            info.status_details_view = new Gtk.Label( "" );
            info.status_details_view.get_style_context().add_class( "assistant-prerequisite-details" );
            info.status_details_view.no_show_all = true;
            info.status_details_view.set_alignment( 0, 0.5f );
            info.status_details_view.ellipsize = Pango.EllipsizeMode.END;
            info.name_view.show();
            info.status_details_view.show();
            info.busy_view = new LoadingIndicator( ICON_SIZE );
            info.status_container.add_named( info.status_view, STATUS_STACK_DEFAULT );
            info.status_container.add_named( info.  busy_view, STATUS_STACK_BUSY    );
            info.status_container.set_visible_child_name( STATUS_STACK_BUSY );
            info.status_container.show_all();

            prerequisite.status_details_changed.connect( () => { handle_prerequisite_update( prerequisite ); } );

            contents.attach( info.   status_container, 0, 2 * last_prerequisite_index    , 1, 1 );
            contents.attach( info.          name_view, 1, 2 * last_prerequisite_index    , 1, 1 );
            contents.attach( info.status_details_view, 1, 2 * last_prerequisite_index + 1, 1, 1 );

            handle_prerequisite_update( prerequisite );
        }

        private void handle_prerequisite_update( Prerequisite prerequisite )
        {
            var info = prerequisite_infos[ prerequisite ];

            info.increment_jobs( this );
            switch( prerequisite.get_status() )
            {

            case Prerequisite.Status.FULFILLED:
                info.status_view.set_from_icon_name( ICON_NAME_FULFILLED, ICON_SIZE );
                break;

            case Prerequisite.Status.VIOLATED:
                info.status_view.set_from_icon_name( ICON_NAME_VIOLATED, ICON_SIZE );
                complete = false;
                break;

            case Prerequisite.Status.UNKNOWN:
                info.status_view.set_from_icon_name( ICON_NAME_UNKNOWN, ICON_SIZE );
                break;

            default:
                assert_not_reached();

            }
            info.is_violated = prerequisite.get_status() == Prerequisite.Status.VIOLATED;
            info.decrement_jobs( this );

            var status_details = prerequisite.get_status_details();
            info.status_details_view.set_text( status_details );

            if( status_details.length > 0 )
            {
                info.status_details_view.margin_top    =  4;
                info.status_details_view.margin_bottom = 10;
            }
            else
            {
                info.status_details_view.margin_top    = 0;
                info.status_details_view.margin_bottom = 0;
            }
        }

        private int current_prerequisite_pos = -1;
        private int    next_prerequisite_pos =  0;

        public void process_prerequisites()
            requires( prerequisites.size > 0 && current_prerequisite_pos == -1 )
        {
            if( next_prerequisite_pos >= prerequisites.size ) info( "Nothing to process" );
            else
            {
                /* Forward `next_prerequisite_pos` to the first prerequisite,
                 * which isn't fulfilled yet *but* can be fixed.
                 */
                Prerequisite? next_prerequisite = null;
                for( ; next_prerequisite_pos < prerequisites.size; ++next_prerequisite_pos )
                {
                    next_prerequisite = prerequisites[ next_prerequisite_pos ];
                    next_prerequisite.invalidate_status();
                    handle_prerequisite_update( next_prerequisite );
                    if( next_prerequisite.get_status() != Prerequisite.Status.FULFILLED && next_prerequisite.is_fixable() ) break;
                }

                /* If such a prerequisite was found, then process it.
                 */
                if( next_prerequisite != null )
                {
                    current_prerequisite_pos = next_prerequisite_pos++;
                    process_current_prerequisite( true );
                }
            }
        }

        public void prepare()
        {
        }

        private void process_current_prerequisite( bool continue_afterwards )
            requires( current_prerequisite_pos >= 0 && current_prerequisite_pos < prerequisites.size )
        {
            var prerequisite = prerequisites[ current_prerequisite_pos ];
            var info = prerequisite_infos[ prerequisite ];
            info.increment_jobs( this );
            prerequisite.fix.begin( ( obj, res ) =>
                {
                    info.decrement_jobs( this );
                    prerequisite.fix.end( res ); // this is where errors are thrown
                    current_prerequisite_pos = -1;
                    handle_prerequisite_update( prerequisite );
                    if( next_prerequisite_pos == prerequisites.size ) finish_processing();
                    else
                    if( continue_afterwards ) process_prerequisites();
                }
            );
        }

        private void finish_processing()
        {
            next_prerequisite_pos = 0;
            complete = true;
            foreach( var prerequisite in prerequisites )
            {
                if( prerequisite.get_status() == Prerequisite.Status.VIOLATED )
                {
                    complete = false;
                    break;
                }
            }
        }

        private weak AssistantWindow assistant;

        public void set_assistant( AssistantWindow? assistant )
        {
            this.assistant = assistant;
        }

    }

}

