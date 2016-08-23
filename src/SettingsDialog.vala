public class SettingsDialog : Gtk.Dialog
{

    private static const string AREA_EDITOR      = "editor";
    private static const string AREA_INTERACTION = "interaction";
    private static const string AREA_BUILD_TYPES = "build-types";

    private double[] horizontal_scroll_in_preview_thresholds       = {      0,      0.1,      0.3,      0.5 };
    private string[] horizontal_scroll_in_preview_threshold_titles = { "None", "Little", "Medium", "Highly" };

    private Settings settings;
    private Gtk.Stack areas_view = new Gtk.Stack();

    private Gtk.Switch       whitespaces_switch = new Gtk.Switch();
    private Gtk.Switch       horizontal_scroll_in_preview_switch = new Gtk.Switch();
    private Gtk.ComboBoxText horizontal_scroll_in_preview_threshold_chooser;
    private Gtk.Switch       fit_preview_zoom_after_build_switch = new Gtk.Switch();

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public SettingsDialog( Gtk.Window? parent )
    {
    #if DEBUG
        ++_debug_instance_counter;
    #endif

        this.title = "Preferences";
        this.set_default_size( 650, 300 );
        this.set_transient_for( parent );

        settings = Athena.instance.settings;

        populate_interaction_settings();
        populate_editor_settings();
        populate_build_types_settings();

        var areas_switcher = new Gtk.StackSwitcher();
        areas_switcher.stack = areas_view;
        areas_switcher.halign = Gtk.Align.CENTER;

        var vbox = new Gtk.Box( Gtk.Orientation.VERTICAL, 20 );
        vbox.pack_start( areas_switcher, false, false );
        vbox.pack_end  ( areas_view    , true , true  );

        ( (Gtk.Container) get_content_area() ).add( vbox );
        add_button( "Close", Gtk.ResponseType.CLOSE );
        Utils.apply_dialog_style( this );
        show_all();
    }

    ~SettingsDialog()
    {
    #if DEBUG
        --_debug_instance_counter;
    #endif
    }

    private static Gtk.Label create_label( string text )
    {
        var label = new Gtk.Label( text );
        label.set_alignment( 0, 0.5f );
        label.get_style_context().add_class( "label" );
        return label;
    }

    private static Gtk.Label create_description( string text )
    {
        var label = new Gtk.Label( text );
        label.set_alignment( 0, 0.5f );
        label.get_style_context().add_class( "description" );
        label.wrap = true;
        label.wrap_mode = Pango.WrapMode.WORD;
        return label;
    }

    private static Gtk.Label create_section_title( string text )
    {
        var label = new Gtk.Label( text );
        label.set_alignment( 0, 0.5f );
        label.get_style_context().add_class( "section-title" );
        label.get_style_context().add_class( "h4" );
        label.get_style_context().add_class( Granite.StyleClass.H3_TEXT );
        return label;
    }

    private struct Layout
    {
        private int last_line;
        private int last_property_line;

        public Gtk.Grid container { get; private set; }

        public Layout()
        {
            last_line = -1;
            last_property_line = -1;
            container = new Gtk.Grid();
            container.column_spacing = 10;
            container.margin_left    = 12;
            container.margin_right   = 12;
            container.margin_bottom  = 12;
            container.margin_top     = 12;
        }

        public void add_section( string title )
        {
            container.attach( create_section_title( title ), 0, ++last_line, 2, 1 );
        }

        public void add_property( string label )
        {
            container.attach( create_label( label ), 0, ++last_line, 1, 1 );
            last_property_line = last_line;
        }

        public void set_description( string text )
        {
            container.attach( create_description( text ), 0, ++last_line, 2, 1 );
        }

        public void set_controller( Gtk.Widget controller )
        {
            var box = new Gtk.Box( Gtk.Orientation.HORIZONTAL, 0 );
            box.add( controller );
            container.attach( box, 1, last_property_line, 1, 1 );
        }
    }

    private void populate_editor_settings()
    {
        Layout layout = Layout();
        areas_view.add_titled( layout.container, AREA_EDITOR, "Editor" );

        layout.add_section( "Tabs" );

        layout.add_property( "Use whitespaces instead of tabs:" );
        layout.set_controller( whitespaces_switch );
    }

    private void populate_interaction_settings()
    {
        Layout layout = Layout();
        areas_view.add_titled( layout.container, AREA_INTERACTION, "Interaction" );

        layout.add_section( "PDF Preview" );

        layout.add_property( "Enable horizontal scrolling:" );
        layout.set_controller( horizontal_scroll_in_preview_switch );
        layout.set_description( "Controls whether the scrolling through you scrolling device (typically a mouse wheel or a touchpad) shall be limited to vertical scrolling." );
        settings.schema.bind( "horizontal-scroll-in-preview", horizontal_scroll_in_preview_switch, "active", SettingsBindFlags.DEFAULT );

        horizontal_scroll_in_preview_threshold_chooser = new Gtk.ComboBoxText();
        horizontal_scroll_in_preview_threshold_chooser.hexpand = false;
        horizontal_scroll_in_preview_threshold_chooser.can_focus = false;
        for( int i = 0; i < horizontal_scroll_in_preview_thresholds.length; ++i )
        {
            horizontal_scroll_in_preview_threshold_chooser.append( "%d".printf( i ), horizontal_scroll_in_preview_threshold_titles[ i ] );
            if( Math.fabs( settings.horizontal_scroll_in_preview_threshold - horizontal_scroll_in_preview_thresholds[ i ] ) < 1e-8 )
            {
                horizontal_scroll_in_preview_threshold_chooser.active = i;
            }
        }
        horizontal_scroll_in_preview_threshold_chooser.changed.connect( () =>
            {
                var position = horizontal_scroll_in_preview_threshold_chooser.get_active();
                if( position >= 0 && position < horizontal_scroll_in_preview_thresholds.length )
                {
                    settings.horizontal_scroll_in_preview_threshold = horizontal_scroll_in_preview_thresholds[ position ];
                }
            }
        );

        layout.add_property( "How distinct has a horizontal scroll to be in order to be recognized?" );
        layout.set_controller( horizontal_scroll_in_preview_threshold_chooser );
        layout.set_description( "Discards horizontal flutter when scrolling down the PDF preview, which is particularly useful on touchpads." );

        layout.add_property( "Fit source area into screen after building:" );
        layout.set_controller( fit_preview_zoom_after_build_switch );
        layout.set_description( "Reduces the PDF preview's current zoom automatically on demand, if the selected area doesn't fit entirely into the screen." );
        settings.schema.bind( "fit-preview-zoom-after-build", fit_preview_zoom_after_build_switch, "active", SettingsBindFlags.DEFAULT );
    }

    private void populate_build_types_settings()
    {
        var vbox = new Gtk.Box( Gtk.Orientation.VERTICAL, 10 );
        areas_view.add_titled( vbox, AREA_BUILD_TYPES, "Build Types" );
    }

}
