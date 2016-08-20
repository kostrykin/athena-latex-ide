public class BuildLogView : Gtk.Popover
{

    private static Gtk.Image ICON_PREV_COMMAND;
    private static Gtk.Image ICON_NEXT_COMMAND;
    private static Gtk.Image ICON_SUCCESS;
    private static Gtk.Image ICON_FAILURE;

    static construct
    {
        ICON_PREV_COMMAND = new Gtk.Image.from_icon_name( "go-previous-symbolic"      , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_NEXT_COMMAND = new Gtk.Image.from_icon_name( "go-next-symbolic"          , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_SUCCESS      = new Gtk.Image.from_icon_name( "process-completed-symbolic", MainWindow.TOOLBAR_ICON_SIZE );
        ICON_FAILURE      = new Gtk.Image.from_icon_name( "process-error-symbolic"    , MainWindow.TOOLBAR_ICON_SIZE );
    }

    private Gtk.ToolItem icon = new Gtk.ToolItem();
    private Gtk.Label command_view = new Gtk.Label( "" );
    private Gtk.ToolButton btn_prev_command;
    private Gtk.ToolButton btn_next_command;
    private Gtk.Button btn_clear;

    private Gee.List< weak Gtk.TextView > views = new Gee.ArrayList< weak Gtk.TextView >();
    private Gee.List< string > commands = new Gee.ArrayList< string >();
    private Gee.List< bool? > results = new Gee.ArrayList< bool? >();
    private Gtk.Stack stack = new Gtk.Stack();
    private Gtk.Label no_output_screen = new Gtk.Label( "This build step generated no output." );

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public BuildLogView( Gtk.Widget? relative_to )
    {
        Object( relative_to: relative_to );

        #if DEBUG
        ++_debug_instance_counter;
        #endif

        var toolbar = new Gtk.Toolbar();
        var vbox = new Gtk.Box( Gtk.Orientation.VERTICAL, 0 );
        toolbar.set_icon_size( MainWindow.TOOLBAR_ICON_SIZE );

        btn_prev_command = new Gtk.ToolButton( ICON_PREV_COMMAND, null );
        btn_prev_command.can_focus = false;
        btn_prev_command.clicked.connect( () => { --current_position; } );

        btn_next_command = new Gtk.ToolButton( ICON_NEXT_COMMAND, null );
        btn_next_command.can_focus = false;
        btn_next_command.clicked.connect( () => { ++current_position; } );

        var btn_clear_toolitem = new Gtk.ToolItem();
        btn_clear = new Gtk.Button.with_label( "Clear" );
        btn_clear.can_focus = false;
        btn_clear.clicked.connect( clear );
        btn_clear_toolitem.add( btn_clear );

        var command_view_toolitem = new Gtk.ToolItem();
        command_view_toolitem.add( command_view );
        command_view_toolitem.set_expand( true );
        command_view.vexpand = true;
        command_view.set_alignment( 0, 0.5f );
        command_view.name = "build-log-command-view";
        command_view.ellipsize = Pango.EllipsizeMode.END;

        icon.name = "build-log-icon";

        toolbar.add( icon );
        toolbar.add( command_view_toolitem );
        toolbar.add( new Gtk.SeparatorToolItem() );
        toolbar.add( btn_prev_command );
        toolbar.add( btn_next_command );
        toolbar.add( new Gtk.SeparatorToolItem() );
        toolbar.add( btn_clear_toolitem );
        toolbar.set_hexpand( true );
        toolbar.set_vexpand( false );

        no_output_screen.vexpand = true;
        no_output_screen.hexpand = true;
        no_output_screen.set_alignment( 0.5f, 0.5f );
        no_output_screen.get_style_context ().add_class( Granite.StyleClass.H2_TEXT );
        stack.add( no_output_screen );

        vbox.pack_start( toolbar, false, true );
        vbox.pack_end  ( stack  , true , true );
        vbox.show_all();

        stack.set_margin_top   ( 2 );
        stack.set_margin_end   ( 8 );
        stack.set_margin_start ( 8 );        
        stack.set_margin_bottom( 5 );

        add( vbox );
        set_size_request( MainWindow.DEFAULT_WIDTH * 2 / 5, MainWindow.DEFAULT_HEIGHT * 2 / 3 );
        current_position = -1;
        update_navigation();
    }

    ~BuildLogView()
    {
        #if DEBUG
        --_debug_instance_counter;
        #endif
    }

    public void clear()
    {
        var children = stack.get_children().copy();
        children.@foreach( ( c ) => { if( c != no_output_screen ) c.destroy(); } );
        views.clear();
        commands.clear();
        results.clear();
        current_position = -1;
        btn_prev_command.sensitive = false;
        btn_next_command.sensitive = false;
        cleared();
        visible = false;
    }

    public int add_step( string command )
    {
        var buffer = new Gtk.TextBuffer( null );
        var scrolled_window = new Gtk.ScrolledWindow( null, null );
        var text_view = new Gtk.TextView.with_buffer( buffer );
        text_view.editable = false;
        scrolled_window.add( text_view );
        scrolled_window.show_all();
        scrolled_window.get_vadjustment().changed.connect( scroll_to_bottom );
        stack.add( scrolled_window );
        views.add( text_view );
        results.add( null );
        commands.add( command );
        update_navigation();
        return views.size - 1;
    }

    private void scroll_to_bottom( Gtk.Adjustment vadj )
    {
        vadj.set_value( vadj.upper - vadj.page_size );
        vadj.value_changed();
    }

    private void update_navigation()
    {
        btn_prev_command.sensitive = current_position >= 1;
        btn_next_command.sensitive = current_position + 1 < views.size;
    }

    private Gtk.ScrolledWindow get_screen( int position )
    {
        return (Gtk.ScrolledWindow) stack.get_children().nth_data( 1 + position );
    }

    public void set_step_result( int position, bool success )
    {
        results[ position ] = success;
        if( position == current_position ) update_icon();
    }

    public void add_step_output( int position, string text )
    {
        views[ position ].buffer.text += text;
        update_output_screen();
    }

    private int _current_position;
    public  int  current_position
    {
        get
        {
            return _current_position;
        }
        set
        {
            assert( value < views.size );
            _current_position = value;
            if( _current_position >= 0 )
            {
                update_output_screen();
                command_view.set_text( commands[ _current_position ] );
                update_navigation();
                update_icon();
            }
            else
            {
                command_view.set_text( "" );
                reset_icon();
            }
        }
    }

    private void update_output_screen()
    {
        var children = stack.get_children();
        var buffer = views[ _current_position ].buffer;
        stack.set_visible_child( buffer.text.length > 0 ? (Gtk.Widget) get_screen( _current_position ) : no_output_screen );
    }

    private void reset_icon()
    {
        var current_icon = icon.get_child();
        if( current_icon != null ) icon.remove( current_icon );
    }

    private void update_icon()
    {
        reset_icon();
        bool? success = results[ current_position ];
        if( success != null )
        {
            icon.add( success ? ICON_SUCCESS : ICON_FAILURE );
            icon.show_all();
        }
    }

    public signal void cleared();

}
