using Granite.Widgets;


public class MainWindow : Gtk.ApplicationWindow
{

    public static Gtk.IconSize   TOOLBAR_ICON_SIZE = Gtk.IconSize.BUTTON;
    public static Gtk.IconSize HEADERBAR_ICON_SIZE = Gtk.IconSize.LARGE_TOOLBAR;

    private static Gtk.Image ICON_BUILD_IDLE;
    private static Gtk.Image ICON_BUILD_SUCCESS;
    private static Gtk.Image ICON_BUILD_FAILURE;

    private static string INTERMEDIATE_SESSION_FILE_PATH;

    static construct
    {
        ICON_BUILD_IDLE    = new Gtk.Image.from_icon_name( "radio-symbolic"            , HEADERBAR_ICON_SIZE );
        ICON_BUILD_SUCCESS = new Gtk.Image.from_icon_name( "process-completed-symbolic", HEADERBAR_ICON_SIZE );
        ICON_BUILD_FAILURE = new Gtk.Image.from_icon_name( "process-error-symbolic"    , HEADERBAR_ICON_SIZE );

        var config_path = Granite.Services.Paths.user_config_folder.get_path();
        INTERMEDIATE_SESSION_FILE_PATH = Path.build_path( Path.DIR_SEPARATOR_S, config_path, "intermediate-session.xml" );
    }

    public static const string HOTKEY_QUICK_BUILD = "F1";
    public static const string HOTKEY_FULL_BUILD  = "F2";
    public static const string HOTKEY_SAVE        = "<Control>S";
    public static const string HOTKEY_OPEN        = "<Control>O";
    public static const string HOTKEY_NEW         = "<Control>N";
    public static const string HOTKEY_CLOSE       = "<Control>W";
    public static const string HOTKEY_SEARCH      = "<Control>F";

    private static const string MAIN_STACK_EDITOR  = "editor";
    private static const string MAIN_STACK_WELCOME = "welcome";
    private static const string SIDE_STACK_PREVIEW = "preview";
    private static const string SIDE_STACK_HELP    = "help";

    public Editor editor { get; private set; default = new Editor(); }

    private Gtk.HeaderBar  headerbar  = new Gtk.HeaderBar();
    private Gtk.Overlay    overlay    = new Gtk.Overlay();
    private Gtk.Paned      pane       = new Gtk.Paned ( Gtk.Orientation.HORIZONTAL );
    private Gtk.Stack      main_stack = new Gtk.Stack();
    private Gtk.Stack      side_stack = new Gtk.Stack();
    private PdfPreview     preview    = new PopplerPreview();
    private Gtk.AccelGroup hotkeys    = new Gtk.AccelGroup();
    private OverlayBar     build_info;
    private BuildLogView   build_log;
    private Gdk.Cursor     busy_cursor;

    private Gee.List< weak Gtk.Widget > editor_dependent_widgets = new Gee.ArrayList< weak Gtk.Widget >();

    private Gtk.Button btn_new_session  = new Gtk.Button.with_label( "New" );
    private Gtk.Button btn_load_session = new Gtk.Button.with_label( "Switch Session..." );
    private Gtk.Button btn_save_session = new Gtk.Button.with_label( "Save As..." );

    private Gtk.ToolButton btn_build_log;
    private Gtk.Button     btn_quick_build = new Gtk.Button.with_label( "Quick Build" );
    private Gtk.Button     btn_full_build  = new Gtk.Button.with_label( "Full" );

    private BuildManager  builder     = new BuildManager();
    private Gtk.ListStore build_types = new Gtk.ListStore( 1, typeof( string ) );
    private Gtk.ComboBox  build_types_view;

    private struct Build
    {
        CommandSequence.Run batch;
        string source_file_path;
        int source_file_line;

        public Build( CommandSequence.Run batch )
        {
            this.batch = batch;
        }
    }

    private uint8 build_locked = 0;
    private Build? current_build = null;

    private static const uint8 BUILD_LOCKED_BY_EDITOR         = 1 << 0;
    private static const uint8 BUILD_LOCKED_BY_ONGOING_BUILD  = 1 << 1;

    public static const int DEFAULT_WIDTH  = 1300;
    public static const int DEFAULT_HEIGHT =  600;

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public MainWindow( Athena app )
    {
        Object( application: app );

        #if DEBUG
        ++_debug_instance_counter;
        #endif

        this.title = app.program_name;
        this.set_default_size( DEFAULT_WIDTH, DEFAULT_HEIGHT );
        this.window_position = Gtk.WindowPosition.CENTER;
        this.set_hide_titlebar_when_maximized( false );

        this.setup_build_types();
        this.setup_headerbar( app );
        this.setup_welcome_screen( app );
        this.setup_editor();
        this.setup_side_stack();
        this.setup_hotkeys();

        this.build_log = new BuildLogView( btn_build_log );
        this.build_log.name = "build-log";
        this.build_log.cleared.connect( () => { btn_build_log.hide(); } );

        this.build_info = new Granite.Widgets.OverlayBar( overlay );
        this.build_info.set_no_show_all( true );

        this.busy_cursor = new Gdk.Cursor( Gdk.CursorType.WATCH );

        pane.pack1(    overlay,  true,  true );
        pane.pack2( side_stack, false, false );
        this.overlay.add( editor );
        this.add( main_stack );
        this.add_accel_group( hotkeys );

        foreach( var w in editor_dependent_widgets ) w.sensitive = false;

        preview.source_requested.connect( ( file_path, line ) =>
            {
                if( editor.open_file_from( file_path ) != null ) editor.current_file_line = line;
            }
        );

        Athena.instance.change_cursor.connect( ( c ) => { get_window().set_cursor( c ); } );
        set_buildable( BUILD_LOCKED_BY_EDITOR, !editor.is_buildable() );

        delete_event.connect( () =>
            {
                save_session();
                return !editor.announce_to_close_all_files();
            }
        );
    }

    ~MainWindow()
    {
        #if DEBUG
        --_debug_instance_counter;
        #endif
    }

    private void setup_build_types()
    {
        builder.@foreach( ( build_type_name, cmd_seq ) =>
            {
                Gtk.TreeIter itr;
                build_types.append( out itr );
                build_types.set( itr, 0, build_type_name );
            }
        );
    }

    public void request_build_type( uint build_type_flags )
    {
        var build_name = builder.resolve_build_type( build_type_flags );

        int candidate_idx = -1;
        Gtk.TreeIter itr;
        build_types.get_iter_first( out itr );
        do
        {
            ++candidate_idx;
            string candidate_name;
            build_types.@get( itr, 0, out candidate_name );
            if( candidate_name == build_name )
            {
                build_types_view.active = candidate_idx;
                return;
            }
        }
        while( build_types.iter_next( ref itr ) );
        assert_not_reached();
    }

    public override void destroy()
    {
        this.build_log = null;
        this.hotkeys = null;
        base.destroy();
    }

    private delegate void HotkeyHandler( string hotkey );
    private void add_hotkey( string hotkey, HotkeyHandler handler )
    {
        uint acl_key;
        Gdk.ModifierType acl_mod;
        Gtk.accelerator_parse( hotkey, out acl_key, out acl_mod );
        hotkeys.connect( acl_key, acl_mod, Gtk.AccelFlags.VISIBLE,
            ( accel_group, acceleratable, keyval, modifier ) =>
            {
                handler( hotkey );
                return true; // we have to return `true` here, because otherwise Gtk
            }                // delivers the hotkey event twice when the focus changes
        );                   // during the processing of that hotkey
    }

    private void handle_build_hotkey( string hotkey )
    {
        Gtk.Button? btn = null;
        switch( hotkey )
        {

        case HOTKEY_QUICK_BUILD:
            btn = btn_quick_build;
            break;

        case HOTKEY_FULL_BUILD:
            btn = btn_full_build;
            break;

        default:
            assert_not_reached();

        }
        if( btn.is_sensitive() ) btn.clicked();
    }

    private void setup_hotkeys()
    {
        add_hotkey( HOTKEY_QUICK_BUILD, handle_build_hotkey );
        add_hotkey( HOTKEY_FULL_BUILD , handle_build_hotkey );
        add_hotkey( HOTKEY_CLOSE      , () => { if( editor.current_file != null ) editor.close_current_file(); } );
        add_hotkey( HOTKEY_SAVE       , () => { if( editor.current_file != null ) editor.save_current_file (); } );
        add_hotkey( HOTKEY_OPEN       , editor.open_file     );
        add_hotkey( HOTKEY_NEW        , editor.open_new_file );
        add_hotkey( HOTKEY_SEARCH     , editor.toggle_search );
    }

    private void hotkey_new( string hotkey )
    {
        stdout.printf("hotkey: %s; null? %s\n", hotkey, editor.current_file==null?"y":"n");
    }

    private void setup_headerbar( Athena app )
    {
        var mnu_settings = new Gtk.MenuItem.with_label( "Preferences" );
        mnu_settings.activate.connect( () =>
            {
                var dlg = new SettingsDialog( this );
                dlg.run();
                dlg.destroy();
            }
        );

        var mnu_search = new Gtk.MenuItem.with_label( "Search..." );
        mnu_search.activate.connect( editor.toggle_search );
        editor_dependent_widgets.add( mnu_search );

        var app_menu = new Gtk.Menu();
        app_menu.add( mnu_search );
        app_menu.add( new Gtk.SeparatorMenuItem() );
        app_menu.add( mnu_settings );

        headerbar.show_close_button = true;
        headerbar.get_style_context().add_class( "primary-toolbar" );
        headerbar.pack_end( app.create_appmenu( app_menu ) );

        btn_new_session.name = "btn-new-session";
        btn_new_session.can_focus = false;
        btn_new_session.tooltip_text = "Closes the current session and starts a new one from scratch.";
        btn_new_session.clicked.connect( () => { start_new_session(); } );

        btn_load_session.name = "btn-load-session";
        btn_load_session.can_focus = false;
        btn_load_session.tooltip_text = "Switches to another, previously saved session.";
        btn_load_session.clicked.connect( load_another_session );

        btn_save_session.name = "btn-save-session";
        btn_save_session.can_focus = false;
        btn_save_session.tooltip_text = "Sets the file, which is to be used for keeping track of the current session.";
        btn_save_session.clicked.connect( save_session_as );

        var session_box = new Gtk.Box( Gtk.Orientation.HORIZONTAL, 0 );
        var session_box_toolitem = new Gtk.ToolItem();
        session_box.add( btn_new_session );
        session_box.add( btn_load_session );
        session_box.add( btn_save_session );
        session_box_toolitem.add( session_box );
        headerbar.pack_start( session_box_toolitem );

        btn_full_build.name = "btn-full-build";
        btn_full_build.can_focus = false;
        btn_full_build.tooltip_text = "Runs BibTeX and LaTeX twice. Updates all references and citations. %s".printf( Utils.format_hotkey( HOTKEY_FULL_BUILD ) );
        btn_full_build.clicked.connect( () => { invoke_build( "full" ); } );

        btn_quick_build.name = "btn-quick-build";
        btn_quick_build.can_focus = false;
        btn_quick_build.tooltip_text = "Only runs LaTeX. May produce outdated references or citations. %s".printf( Utils.format_hotkey( HOTKEY_QUICK_BUILD ) );
        btn_quick_build.clicked.connect( () => { invoke_build( "quick" ); } );

        var box = new Gtk.Box( Gtk.Orientation.HORIZONTAL, 0 );
        var box_toolitem = new Gtk.ToolItem();
        box.pack_end( btn_quick_build );
        box.pack_end( btn_full_build );
        box_toolitem.add( box );
        box_toolitem.show_all();
        headerbar.pack_end( new Gtk.SeparatorToolItem() );
        headerbar.pack_end( box_toolitem );

        build_types_view = new Gtk.ComboBox.with_model( build_types );
        var build_types_view_toolitem = new Gtk.ToolItem();
        build_types_view_toolitem.add( build_types_view );
        var build_types_name_renderer = new Gtk.CellRendererText();
        build_types_view.pack_start( build_types_name_renderer, true );
        build_types_view.add_attribute( build_types_name_renderer, "text", 0 );
        build_types_view.active = 0;
        build_types_view.show_all();

        headerbar.pack_end( build_types_view_toolitem );

        btn_build_log = new Gtk.ToolButton( ICON_BUILD_IDLE, null );
        btn_build_log.show_all();
        btn_build_log.hide();
        btn_build_log.set_no_show_all( true );
        btn_build_log.clicked.connect( toggle_build_log );
        headerbar.pack_end( new Gtk.SeparatorToolItem() );
        headerbar.pack_end( btn_build_log );

        this.set_titlebar( headerbar );
    }

    /**
     * Prompts the user if there are any unsaved files and resets the current session to vanilla state.
     *
     * Does not prompt the user if `force` is set to `true`.
     * Returns `false` only when the user cancels, returns `true` otherwise.
     */
    private bool reset_session( bool force = false )
        ensures( !force || ( force && result ) ) // force => result
    {
        var current_session = Athena.instance.settings.current_session; // save the current session file path,
        if( !editor.close_all_files( !force ) ) return false;           // because closing all files starts a new session
        Athena.instance.settings.current_session = current_session;     // and then reset the file path to the saved one
        update_headerbar_title();

        main_stack.set_visible_child_name( MAIN_STACK_WELCOME );
        build_log.clear();
        editor.session.output_path = null;
        update_preview();

        foreach( var w in editor_dependent_widgets ) w.sensitive = false;
        return true;
    }

    /**
     * Prompts the user if there are any unsaved files and starts a new vanilla session.
     */
    public void start_new_session( bool save_current = true )
    {
        if( !is_session_intermediate && save_current ) save_session();
        if( reset_session() )
        {
            Athena.instance.settings.current_session = "";
            update_headerbar_title();
            info( "Started new intermediate session" );
        }
    }

    public void load_another_session()
    {
        if( !is_session_intermediate ) save_session();
        if( !editor.announce_to_close_all_files() ) return;
        FileDialog.choose_readable_file_and( this, ( path ) =>
            {
                Athena.instance.settings.current_session = path;
                update_headerbar_title();
                reload_session();
            }
        );
    }

    /**
     * Reloads the current session.
     */
    public void reload_session( bool allow_empty = false )
    {
        reset_session( true ); // this is (a) just to be sure and (b) to suffice the method's name

        if( !is_session_intermediate || FileUtils.test( session_file_path, FileTest.EXISTS ) )
        {
            string error = "";
            Athena.instance.override_cursor( busy_cursor );
            
            try
            {
                var xml = new SessionXml( editor );
                xml.read_from( session_file_path );
                update_preview();
                build_types_view.active = xml.build_type_position;
            
                if( editor.get_source_views().size > 0 )
                {
                    main_stack.set_visible_child_name( MAIN_STACK_EDITOR );
                    initialize_editor_pane();
                }
                else
                if( !allow_empty ) error = "The session contains no loadable files.";
            }
            catch( XmlError xml_error )
            {
                error = xml_error.message;
            }
            finally
            {
                Athena.instance.restore_cursor();
            }
            if( error.length > 0 )
            {
                warning( "Failed to reload session: %s", error );
                editor.close_all_files( false );
                start_new_session( false );

                var dlg = new Gtk.MessageDialog(  this
                                               ,  Gtk.DialogFlags.MODAL
                                               ,  Gtk.MessageType.ERROR
                                               ,  Gtk.ButtonsType.NONE
                                               , "The session could not be loaded." );

                dlg.add_button( "Start New"     , 0 );
                dlg.add_button( "Load Different", 1 );
                Utils.apply_dialog_style( dlg );

                dlg.secondary_text = "The reason was: %s\n\nWould you like to load a different session instead?".printf( error );
                dlg.set_default_response( 1 );
                dlg.set_transient_for( this );

                var dlg_result = dlg.run();
                dlg.destroy();

                if( dlg_result == 1 ) load_another_session();
            }
            else info( "Reloaded session %s", session_file_path );
        }
        else info( "Initial intermediate session - There is nothing to reload" );
    }

    public void save_session_as()
    {
        FileDialog.choose_writable_file_and( this, ( path ) =>
            {
                Athena.instance.settings.current_session = path ?? "";
                update_headerbar_title();
                save_session();
            }
        );
    }

    private void save_session()
    {
        var xml = new SessionXml( editor );
        xml.build_type_position = build_types_view.active;
        xml.write_to( session_file_path );
        info( "Saved session to %s", session_file_path );
    }

    public bool is_session_intermediate { get { return Athena.instance.settings.current_session.length == 0; } }

    private string session_file_path { get { return is_session_intermediate ? INTERMEDIATE_SESSION_FILE_PATH : Athena.instance.settings.current_session; } }

    private void update_headerbar_title()
    {
        headerbar.title = is_session_intermediate ? "Intermediate Session" : Athena.instance.settings.current_session;
    }

    public void toggle_build_log()
    {
        build_log.visible = !build_log.visible;
    }

    private void setup_welcome_screen( Athena app )
    {
        var welcome = new Welcome( "Athena LaTeX IDE", "Choose your start:" );

        welcome.append( "document-page-setup", "Start a Project", "Follow a few guided steps to create a new project.");
        welcome.append( "document-new", "New .TeX File", "Start with an empty LaTeX file.");
        welcome.append( "document-open", "Open", "Continue from a previously saved file or session." );

        main_stack.add_named( welcome, MAIN_STACK_WELCOME );

        var self = this;
        welcome.activated.connect( ( index ) =>
            {
                switch( index )
                {

                case 0:
                    self.start_project();
                    break;

                case 1:
                    editor.open_new_file();
                    break;

                case 2:
                    editor.open_file();
                    break;

                }
            }
        );
    }

    private void setup_side_stack()
    {
        var help = new Gtk.Box( Gtk.Orientation.VERTICAL, 15 );
        help.name = "help";
        help.pack_start( new Gtk.Label( "" ), true, true );
        help.pack_end  ( new Gtk.Label( "" ), true, true );

        var howto_title = new Gtk.Label( "How to Build" );
        howto_title.get_style_context().add_class( Granite.StyleClass.H2_TEXT );
        howto_title.use_markup = true;
        howto_title.wrap = true;
        howto_title.wrap_mode = Pango.WrapMode.WORD;
        howto_title.set_alignment( 0.5f, 0 );
        help.add( howto_title );

        var howto = new Gtk.Label( """A <b>Quick Build</b> will be sufficient most of the time. If anything appears out of order, try a <b>Full Build</b>.""" );
        howto.get_style_context().add_class( Granite.StyleClass.H3_TEXT );
        howto.use_markup = true;
        howto.wrap = true;
        howto.wrap_mode = Pango.WrapMode.WORD;
        howto.set_alignment( 0, 0 );
        help.add( howto );

        var details = new Gtk.Label( """Consider a <b>Full Build</b> when you changed the <i>bibliography</i>, updated any <i>labels</i> or did some major changes to the document's structure.""" );
        details.get_style_context().add_class( Granite.StyleClass.H3_TEXT );
        details.use_markup = true;
        details.wrap = true;
        details.wrap_mode = Pango.WrapMode.WORD;
        details.set_alignment( 0, 0 );
        help.add( details );

        side_stack.add_named( preview, SIDE_STACK_PREVIEW );
        side_stack.add_named( help   , SIDE_STACK_HELP    );
    }

    private void setup_editor()
    {
        main_stack.add_named( pane, MAIN_STACK_EDITOR );
        editor.file_opened.connect( () =>
            {
                if( editor.files_count == 1 ) Idle.add( () => { show_editor(); return false; } );
            }
        );
        editor.file_closed.connect( () =>
            {
                if( editor.files_count == 0 ) start_new_session( false );
            }
        );
        editor.buildable_invalidated.connect( () =>
            {
                set_buildable( BUILD_LOCKED_BY_EDITOR, !editor.is_buildable() );
            }
        );
    }

    private void set_buildable( uint8 flag, bool on )
    {
        if( on )
        {
            build_locked |= flag;
        }
        else
        {
            build_locked ^= flag & build_locked;
        }
        bool buildable = build_locked == 0;
        btn_quick_build.sensitive = buildable;
        btn_full_build .sensitive = buildable;
    }

    private void start_project()
    {
        var assistant = new Assistant.AssistantWindow( this );
        assistant.show_all();
    }

    private void initialize_editor_pane()
    {
        foreach( var w in editor_dependent_widgets ) w.sensitive = true;

        Athena.process_events();

        int pane_position;
        build_types_view.translate_coordinates( pane, 0, 0, out pane_position, null );
        pane.position = pane_position;

        Athena.process_events();

        int window_width = overlay.get_allocated_width() + side_stack.get_allocated_width(); // `get_allocated_width` misses 100px... -,-
        side_stack.set_size_request( window_width - pane_position, 200 );
    }

    private void show_editor()
    {
        update_preview();
        main_stack.set_visible_child_name( MAIN_STACK_EDITOR );
        initialize_editor_pane();
    }

    public void invoke_build( string mode )
    {
        /* We make some extra tests here as a preventative for future bugs.
         */
        if( build_locked == 0 && current_build == null && editor.is_buildable() )
        {
            /* For convenience, we automatically save the currently open file, unless it has a conflict.
             */
            if( editor.current_file.has_flags( Session.FLAGS_MODIFIED ) && !editor.current_file.has_flags( Session.FLAGS_CONFLICT ) )
            {
                editor.save_current_file();
            }

            Gtk.TreeIter itr;
            build_types.get_iter_from_string( out itr, "%u".printf( build_types_view.active ) );

            Value build_type_name;
            build_types.get_value( itr, 0, out build_type_name );

            var commands  = builder[ (string) build_type_name ];
            var context   = builder.create_build_context( editor.build_input );

            editor.session.output_path = "%s.pdf".printf( context.variables[ BuildManager.VAR_OUTPUT ] );

            build_log.clear();
            set_build_result( null );

            current_build = new Build( commands.prepare_run( context, mode ) );
            current_build.batch.step.connect( update_build_info );
            current_build.batch.done.connect( ( build, result ) => { exit_build( mode, result == 0 ); } );
            current_build.batch.stdout_changed.connect( append_build_log );
            current_build.batch.special_command.connect( ( build, command ) => { handle_special_command( build, command, context ); } );
            current_build.source_file_path = editor.current_file.path;
            current_build.source_file_line = editor.current_file_line;
            current_build.batch.start();

            set_buildable( BUILD_LOCKED_BY_ONGOING_BUILD, true );
            Athena.instance.override_cursor( busy_cursor );
        }
    }

    private void append_build_log( CommandSequence.Run build, string text )
    {
        build_log.add_step_output( build_log.current_position, text );
    }

    private void handle_special_command( CommandSequence.Run build, string command, CommandContext context )
    {
        switch( command )
        {

            case BuildManager.COMMAND_INIT:
                init_build( build, context );
                break;

            case BuildManager.COMMAND_PREVIEW:
                update_preview();
                break;

            default:
                assert_not_reached();
        }
    }

    private void init_build( CommandSequence.Run build, CommandContext context )
    {
        DirUtils.create_with_parents( build.dir, 493 ); // 493 is 755 in octal
        int longest_key = 0;
        foreach( var key in context.variables.keys ) longest_key = Utils.max( longest_key, key.length );
        var format = "%" + longest_key.to_string() + "s = %s\n";
        foreach( var key in context.variables.keys ) append_build_log( build, format.printf( key, context.variables[ key ] ) );
    }

    private void update_preview()
    {
        /* The `pdf_path` update reloads the preview and re-initializes synctex implicitly.
         */
        preview.pdf_path = editor.session.output_path;
        side_stack.set_visible_child_name( editor.session.output_path == null ? SIDE_STACK_HELP : SIDE_STACK_PREVIEW );

        if( current_build != null )
        {
            if( !preview.show_from_source( current_build.source_file_path, current_build.source_file_line ) )
            {
                warning( "SyncTex display query failed for \"%s\"", current_build.source_file_path );
            }
        }
    }

    private void update_build_info( CommandSequence.Run build )
    {
        if( build.position < build.commands.length )
        {
            var cmd = build.commands[ build.position ];
            build_info.status = "Build: %s (step %d of %d)".printf( cmd, build.position + 1, build.commands.length );
            build_info.show();
            build_log.current_position = build_log.add_step( cmd );
            build_log.set_step_result( build_log.current_position, true );
            message( @"build> $cmd" );
        }
    }

    private void set_build_result( bool? success )
    {
        if( success != null )
        {
            btn_build_log.set_icon_widget( success ? ICON_BUILD_SUCCESS : ICON_BUILD_FAILURE );
            build_log.set_step_result( build_log.current_position, success );
        }
        else btn_build_log.set_icon_widget( ICON_BUILD_IDLE );

        btn_build_log.set_no_show_all( false );
        btn_build_log.show_all();
        btn_build_log.set_no_show_all( true );
    }

    private void exit_build( string mode, bool success )
    {
        Athena.instance.restore_cursor();
        set_build_result( success );
        if( !success ) build_log.show();

        var timeout = new TimeoutSource( 1000 );
        timeout.set_callback( () =>
            {
                set_buildable( BUILD_LOCKED_BY_ONGOING_BUILD, false );
                current_build = null;
                build_info.hide();
                return false;
            }
        );
        timeout.attach( null );

    }

}
