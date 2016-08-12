using Granite.Widgets;


public class MainWindow : Gtk.Window
{

    private Gtk.Overlay overlay = new Gtk.Overlay();
    private Gtk.Paned   pane    = new Gtk.Paned ( Gtk.Orientation.HORIZONTAL );
    private Gtk.Stack   stack   = new Gtk.Stack();
    private Editor      editor  = new Editor();
    private PdfPreview  preview = new PopplerPreview();

    private Granite.Widgets.OverlayBar build_info;

    private Gtk.Button btn_quick_build = new Gtk.Button.with_label( "Quick Build" );
    private Gtk.Button btn_full_build  = new Gtk.Button.with_label( "Full" );

    private BuildManager  builder     = new BuildManager();
    private Gtk.ListStore build_types = new Gtk.ListStore( 1, typeof( string ) );
    private Gtk.ComboBox  build_types_view;

    private uint8 build_locked = 0;
    private CommandSequence.Run? current_build = null;

    private static const uint8 BUILD_LOCKED_BY_EDITOR         = 1 << 0;
    private static const uint8 BUILD_LOCKED_BY_ONGOING_BUILD  = 1 << 1;

    private static const int DEFAULT_WIDTH  = 1300;
    private static const int DEFAULT_HEIGHT =  600;

    public MainWindow( Athena app )
    {
        this.title = app.program_name;
        this.set_default_size( DEFAULT_WIDTH, DEFAULT_HEIGHT );
        this.window_position = Gtk.WindowPosition.CENTER;
        this.set_hide_titlebar_when_maximized( false );

        this.setup_build_types();
        this.setup_headerbar( app );
        this.setup_welcome_screen( app );
        this.setup_editor();

        this.build_info = new Granite.Widgets.OverlayBar( overlay );
        this.build_info.set_no_show_all( true );

        pane.pack1( overlay,  true,  true );
        pane.pack2( preview, false, false );
        this.overlay.add( editor );
        this.add( stack );

        set_buildable( 0, false );
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

    private void setup_headerbar( Athena app )
    {
        var headerbar = new Gtk.HeaderBar();
        headerbar.title = "Intermediate Session";
        headerbar.show_close_button = true;
        headerbar.get_style_context().add_class( "primary-toolbar" );
        headerbar.pack_end( app.create_appmenu( new Gtk.Menu() ) );

        btn_full_build.name = "btn-full-build";
        btn_full_build.can_focus = false;
        btn_full_build.tooltip_text = "Runs BibTeX and LaTeX twice. Updates all references and citations.";
        btn_full_build.clicked.connect( () => { invoke_build( "full" ); } );

        btn_quick_build.name = "btn-quick-build";
        btn_quick_build.can_focus = false;
        btn_quick_build.tooltip_text = "Only runs LaTeX. May produce outdated references or citations.";
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

        this.set_titlebar( headerbar );
    }

    private void setup_welcome_screen( Athena app )
    {
        var welcome = new Welcome( app.program_name, "documents & presentations as they are meant to be" );

        welcome.append( "document-page-setup", "Start a Project", "Follow a few guided steps to create a new project.");
        welcome.append( "document-new", "New .TeX File", "Start with an empty LaTeX file.");
        welcome.append( "document-open", "Open", "Continue from a previously saved file or session." );

        stack.add_named( welcome, "welcome" );

        var self = this;
        welcome.activated.connect( ( index ) =>
            {
                switch( index )
                {

                case 0:
                    self.start_project();
                    break;

                case 1:
                    self.open_new_file();
                    break;

                case 2:
                    self.open_previous();
                    break;

                }
            }
        );
    }

    private void setup_editor()
    {
        stack.add_named( pane, "editor" );
        editor.file_closed.connect( () =>
            {
                if( editor.files_count == 0 )
                {
                    stack.set_visible_child_name( "welcome" );
                }
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
    }

    private void initialize_editor_pane()
    {
        if( pane.position == 0 )
        {
            int pane_position;
            Gtk.Allocation alloc;
            build_types_view.get_allocation( out alloc );
            build_types_view.translate_coordinates( this, -alloc.width / 2 - 3, 0, out pane_position, null );
            pane.position = pane_position;
        }
    }

    private void open_new_file()
    {
        initialize_editor_pane();
        editor.open_new_file();
        stack.set_visible_child_name( "editor" );

        preview.pdf_path = "/tmp/.build/test.pdf"; // FIXME: debug
    }

    private void open_previous()
    {
        FileDialog.choose_readable_file_and( ( path ) =>
            {
                if( path != null )
                {
                    initialize_editor_pane();
                    editor.open_file_from( path );
                    stack.set_visible_child_name( "editor" );
                }
            }
        );
    }

    public void invoke_build( string mode )
    {
        /* We make some extra tests here as a preventative for future bugs.
         */
        if( build_locked == 0 && current_build == null && editor.is_buildable() )
        {
            Gtk.TreeIter itr;
            build_types.get_iter_from_string( out itr, "%u".printf( build_types_view.active ) );

            Value build_type_name;
            build_types.get_value( itr, 0, out build_type_name );

            var commands  = builder[ (string) build_type_name ];
            var context   = builder.create_build_context( editor.build_input );

            editor.session.output_path = "%s.pdf".printf( context.variables[ BuildManager.VAR_OUTPUT ] );

            current_build = commands.prepare_run( context, mode );
            current_build.step.connect( update_build_info );
            current_build.done.connect( ( build, result ) => { exit_build( mode, result == 0 ); } );
            current_build.special_command.connect( handle_special_command );
            current_build.start();

            set_buildable( BUILD_LOCKED_BY_ONGOING_BUILD, true );
        }
    }

    private void handle_special_command( CommandSequence.Run build, string command )
    {
        switch( command )
        {

            case BuildManager.COMMAND_PREVIEW:
                update_preview();
                break;

            default:
                // TODO: throw error
                break;
        }
    }

    private void update_preview()
    {
        /* Reloads the preview implicitly.
         */
        preview.pdf_path = editor.session.output_path;
    }

    private void update_build_info( CommandSequence.Run build )
    {
        if( build.position < build.commands.length )
        {
            var cmd = build.commands[ build.position ];
            build_info.status = "Build: %s (step %d of %d)".printf( cmd, build.position + 1, build.commands.length );
            build_info.show();
            message( @"build> $cmd" );
        }
    }

    private void exit_build( string mode, bool success )
    {
        // ...
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
