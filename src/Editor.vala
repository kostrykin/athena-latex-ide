public class Editor : Gtk.Box
{

    private static Gtk.Image ICON_NEW;
    private static Gtk.Image ICON_OPEN;
    private static Gtk.Image ICON_SAVE;
    private static Gtk.Image ICON_CLOSE;
    private static Gtk.Image ICON_DETAILS;

    private static const int CONFLICT_RESOLVE_SAVE   = 0;
    private static const int CONFLICT_RESOLVE_RELOAD = 1;
    private static const int CONFLICT_RESOLVE_IGNORE = 2;

    static construct
    {
        ICON_NEW     = new Gtk.Image.from_icon_name( "document-new-symbolic" , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_OPEN    = new Gtk.Image.from_icon_name( "document-open-symbolic", MainWindow.TOOLBAR_ICON_SIZE );
        ICON_SAVE    = new Gtk.Image.from_icon_name( "document-save-symbolic", MainWindow.TOOLBAR_ICON_SIZE );
        ICON_CLOSE   = new Gtk.Image.from_icon_name( "window-close-symbolic" , MainWindow.TOOLBAR_ICON_SIZE );
        ICON_DETAILS = new Gtk.Image.from_icon_name( "open-menu-symbolic"    , MainWindow.TOOLBAR_ICON_SIZE );
    }

    private Gtk.ListStore    files           = new Gtk.ListStore( 3, typeof( string ), typeof( string ), typeof( string ) );
    private Gtk.Stack        stack           = new Gtk.Stack(); 
    private Gtk.Toolbar      toolbar         = new Gtk.Toolbar();
    private Gtk.MenuItem     mnu_reload      = new Gtk.MenuItem.with_label( "Reload" );
    private Gtk.ToggleButton btn_master      = new Gtk.ToggleButton.with_label( "Master" );
    private Gtk.Revealer     search_revealer = new Gtk.Revealer();
    private SearchManager    search_manager;
    private Gtk.ComboBox     files_view;

    private Gtk.InfoBar conflict_info_bar = new Gtk.InfoBar();
    private Gtk.InfoBar conflict_tool_bar = new Gtk.InfoBar();

    private Gee.Map< SourceFileManager.SourceFile, SourceFileView > source_views = new Gee.HashMap< SourceFileManager.SourceFile, SourceFileView >();

    public Session session { private set; public get; default = new Session(); }
    public SourceFileManager.SourceFile? current_file { private set; public get; }

    public signal void file_opened( SourceFileManager.SourceFile file );
    public signal void file_closed( SourceFileManager.SourceFile file );
    public signal void file_saved ( SourceFileManager.SourceFile file );
    public signal void current_file_changed();
    public signal void buildable_invalidated();

    private bool handle_files_view_changes = true;

    public FeatureCompletionProvider     ref_completion_provider { public get; private set; }
    public FeatureCompletionProvider   eqref_completion_provider { public get; private set; }
    public FeatureCompletionProvider    cite_completion_provider { public get; private set; }
    public FeatureCompletionProvider   citep_completion_provider { public get; private set; }
    public FeatureCompletionProvider   citet_completion_provider { public get; private set; }
    public CommandCompletionProvider command_completion_provider { public get; private set; }

    #if DEBUG
    public static uint _debug_instance_counter = 0;
    #endif

    public Editor()
    {
        #if DEBUG
        ++_debug_instance_counter;
        #endif

        Object( orientation: Gtk.Orientation.VERTICAL, spacing: 0 );
        this.setup_infobars();
        this.pack_start( conflict_info_bar, false );
        this.setup_toolbar();
        this.setup_search();
        this.pack_end( search_revealer, false, true );
        this.pack_end( stack, true, true );
        this.pack_end( conflict_tool_bar, false );
        this.stack.show();

        this.session.files.invalidated.connect( update_files_model );

        this.    ref_completion_provider = new FeatureCompletionProvider( this, SourceStructure.Feature.LABEL    , "ref"  , "Labels"     );
        this.  eqref_completion_provider = new FeatureCompletionProvider( this, SourceStructure.Feature.LABEL    , "eqref", "Labels"     );
        this.   cite_completion_provider = new FeatureCompletionProvider( this, SourceStructure.Feature.BIB_ENTRY, "cite" , "References" );
        this.  citep_completion_provider = new FeatureCompletionProvider( this, SourceStructure.Feature.BIB_ENTRY, "citep", "References" );
        this.  citet_completion_provider = new FeatureCompletionProvider( this, SourceStructure.Feature.BIB_ENTRY, "citet", "References" );
        this.command_completion_provider = new CommandCompletionProvider( this );
    }

    ~Editor()
    {
        #if DEBUG
        --_debug_instance_counter;
        #endif
    }

    public override void destroy()
    {
        this.session = null;
        base.destroy();
    }

    private void setup_search()
    {
        weak Editor weak_this = this;

        search_manager = new SearchManager( this );
        search_manager.get_style_context().add_class( "search-bar" );
        search_manager.need_hide.connect( weak_this.hide_search );

        search_revealer.add( search_manager );
        search_revealer.show_all();
        search_revealer.reveal_child = false;
    }

    private void setup_infobars()
    {
        /* Don't show the info bars when `show_all` is called on `this` widget.
         */
        conflict_info_bar.set_no_show_all( true );
        conflict_tool_bar.set_no_show_all( true );
        conflict_info_bar.set_message_type( Gtk.MessageType.ERROR );
        conflict_tool_bar.set_message_type( Gtk.MessageType.WARNING );

        Gtk.Label label;

        label = new Gtk.Label( null );
        label.set_markup( "<b>One or more open files have been changed by another user or program!</b>" );
        conflict_info_bar.get_content_area().add( label );
        label.show();

        label = new Gtk.Label( "This file has been changed by another user or program. How do you want to proceed?" );
        conflict_tool_bar.get_content_area().add( label );
        label.show();

        conflict_info_bar.add_button( "_Show", Gtk.ResponseType.OK );
        conflict_info_bar.response.connect( show_next_conflict );

        conflict_tool_bar.add_button( "_Save"  , CONFLICT_RESOLVE_SAVE   );
        conflict_tool_bar.add_button( "_Reload", CONFLICT_RESOLVE_RELOAD );
        conflict_tool_bar.add_button( "_Ignore", CONFLICT_RESOLVE_IGNORE );
        conflict_tool_bar.response.connect( ( resolve ) =>
            {
                switch( resolve )
                {
                    case CONFLICT_RESOLVE_SAVE:
                        save_current_file();
                        break;

                    case CONFLICT_RESOLVE_RELOAD:
                        reload_current_file();
                        break;

                    default:
                        break;
                }
                resolve_conflict( current_file );
            }
        );
    }

    private void show_next_conflict()
    {
        if( !current_file.has_flags( Session.FLAGS_CONFLICT ) )
        {
            foreach( var file in session.files )
            {
                if( file.has_flags( Session.FLAGS_CONFLICT ) )
                {
                    set_current_file_position( file.position );
                    return;
                }
            }
        }
    }

    private void denote_conflict( SourceFileManager.SourceFile file )
    {
        session.files.set_flags( file.position, Session.FLAGS_MODIFIED );
        session.files.set_flags( file.position, Session.FLAGS_CONFLICT );

        var source_view = source_views[ file ];
        source_view.set_sensitive( false );

        if( file == current_file )
        {
            conflict_tool_bar.show();
        }

        conflict_info_bar.show();
    }

    private void resolve_conflict( SourceFileManager.SourceFile? file )
    {
        if( file != null )
        {
            session.files.set_flags( file.position, Session.FLAGS_CONFLICT, false );

            var source_view = source_views[ file ];
            source_view.set_sensitive( true );
        }

        if( file == current_file )
        {
            conflict_tool_bar.hide();
        }

        bool no_more_conflicts = true;
        foreach( var other_file in session.files )
        {
            if( other_file.has_flags( Session.FLAGS_CONFLICT ) )
            {
                no_more_conflicts = false;
            }
        }
        if( no_more_conflicts )
        {
            conflict_info_bar.hide();
        }
        
    }

    private void setup_toolbar()
    {
        toolbar.set_icon_size( MainWindow.TOOLBAR_ICON_SIZE );

        var btn_new = new Gtk.ToolButton( ICON_NEW, null );
        toolbar.add( btn_new );
        btn_new.clicked.connect( open_new_file );
        btn_new.tooltip_text = "Open New File %s".printf( Utils.format_hotkey( MainWindow.HOTKEY_NEW ) );
        btn_new.show();

        var btn_open = new Gtk.ToolButton( ICON_OPEN, null );
        toolbar.add( btn_open );
        btn_open.clicked.connect( open_file );
        btn_open.tooltip_text = "Load Saved File %s".printf( Utils.format_hotkey( MainWindow.HOTKEY_OPEN ) );
        btn_open.show();

        var btn_save = new Gtk.ToolButton( ICON_SAVE, null );
        toolbar.add( btn_save );
        btn_save.clicked.connect( () => { save_current_file(); } );
        btn_save.tooltip_text = "Save %s".printf( Utils.format_hotkey( MainWindow.HOTKEY_SAVE ) );
        btn_save.show();

        files_view = new Gtk.ComboBox.with_model( files );
        files_view.name = "files-view";
        var files_view_toolitem = new Gtk.ToolItem();
        files_view_toolitem.add( files_view );
        files_view_toolitem.set_expand( true );
        var  text_renderer = new Gtk.CellRendererText();
        var    pb_renderer = new Gtk.CellRendererPixbuf();
        var badge_renderer = new Granite.Widgets.CellRendererBadge();
        files_view.pack_start(    pb_renderer, false );
        files_view.pack_start(  text_renderer, true  );
        files_view.pack_start( badge_renderer, false );
        files_view.add_attribute(    pb_renderer, "icon_name", 0 );
        files_view.add_attribute(  text_renderer,      "text", 1 );
        files_view.add_attribute( badge_renderer,      "text", 2 );
        pb_renderer.set_fixed_size( 20, 16 );
        badge_renderer.set_padding( 10,  0 );
        files_view.show_all();

        files_view.changed.connect( () =>
            {
                if( handle_files_view_changes )
                {
                    var position = files_view.get_active();
                    set_current_file_position( position );
                }
            }
        );

        var btn_close_toolitem = new Gtk.ToolItem();
        var btn_close = new Gtk.Button();
        btn_close.name = "btn-close-current-file";
        btn_close.image = ICON_CLOSE;
        btn_close.can_focus = false;
        btn_close.show();
        btn_close.clicked.connect( () => { close_current_file(); } );
        btn_close.tooltip_text = "Close %s".printf( Utils.format_hotkey( MainWindow.HOTKEY_CLOSE ) );
        btn_close_toolitem.add( btn_close );

        toolbar.add( new Gtk.SeparatorToolItem() );
        toolbar.add( files_view_toolitem );
        toolbar.add( btn_close_toolitem );
        toolbar.add( new Gtk.SeparatorToolItem() );

        var btn_master_toolitem = new Gtk.ToolItem();
        toolbar.add( btn_master_toolitem );
        btn_master_toolitem.add( btn_master );
        btn_master.can_focus = false;
        btn_master.tooltip_text = "Always build this file";
        btn_master.toggled.connect( () =>
            {
                if( btn_master.get_active() ) session.master = current_file;
                else if( session.master == current_file ) session.master = null;
            }
        );
        session.master_changed.connect( handle_master_changed );

        var mnu_save_as = new Gtk.MenuItem.with_label( "Save as..." );
        mnu_save_as.activate.connect( () => { save_current_file_as(); } );
        mnu_reload.activate.connect( reload_current_file );

        var menu = new Gtk.Menu();
        menu.append( mnu_save_as );
        menu.append( mnu_reload  );
        menu.show_all();

        var btn_menu = new Granite.Widgets.ToolButtonWithMenu( ICON_DETAILS, "", menu );
        toolbar.add( new Gtk.SeparatorToolItem() );
        toolbar.add( btn_menu );

        toolbar.set_hexpand( true );
	this.pack_start( toolbar, false );
	toolbar.show();
    }

    public void open_new_file()
    {
        open_file_from( null );
    }

    public void open_file()
    {
        FileDialog.choose_readable_file_and( get_dialog_parent(), ( path ) => { open_file_from( path ); } );
    }

    private Gtk.Window get_dialog_parent()
    {
        return get_toplevel() as Gtk.Window;
    }

    /**
     * Opens the file from `path` in the editor, or a blank file if `path` is `null`.
     *
     * Returns a representation of the opened file, that is only `null`, if an error occures.
     * Such error is reported to the user.
     * This method ensures that no file is opened more than once at the same time.
     * If the file, which `path` points to, is already open,
     * then its view is focused and its already loaded representation returned.
     */
    public SourceFileManager.SourceFile? open_file_from( string? path )
    {
        var position = path != null ? session.files.find_position( path ) : -1;
        if( position < 0 )
        {
            string? error = null;
            try
            {
                var file = session.files.open( path );
                add_source_view( file );

                /* We need now to switch to the newly added source view.
                 */
                set_current_file_position( file.position );

                /* We've done with opening the file.
                 */
                file_opened( file );
                return file;
            }
            catch( SourceFileError.NOT_FOUND err )
            {
                error = "The file doesn't exist.";
            }
            if( error != null )
            {
                var dlg = new Gtk.MessageDialog(  get_dialog_parent()
                                               ,  Gtk.DialogFlags.MODAL
                                               ,  Gtk.MessageType.ERROR
                                               ,  Gtk.ButtonsType.CLOSE
                                               , "Couldn't open %s".printf( path ) );

                Utils.apply_dialog_style( dlg );

                dlg.secondary_text = error;
                dlg.set_transient_for( get_dialog_parent() );

                dlg.run();
                dlg.destroy();
            }
            return null;
        }
        else
        {
            /* Obviously the file from `path` is already opened, so lets bring it to front.
             */
            files_view.active = position;
            return current_file;
        }
    }

    public void reload_current_file()
    {
        var source_view = source_views[ current_file ];
        source_view.buffer.text = current_file.get_contents();
        session.files.set_flags( current_file.position, Session.FLAGS_MODIFIED, false );
    }

    private void handle_master_changed( SourceFileManager.SourceFile? old )
    {
        btn_master.set_active( session.master == current_file );
        if( old != null ) update_files_model( old.position, 1 );
        update_files_model( current_file.position, 1 );
        buildable_invalidated();
    }

    private void add_source_view( SourceFileManager.SourceFile file )
    {
        weak Editor weak_this = this;
        var source_view = new SourceFileView( this, file );
        source_view.buffer.text = file.get_contents();
        file.changed.connect( weak_this.handle_file_changed );
        stack.add( source_view );
        source_views[ file ] = source_view;
        source_view.show_all();
    }

    private void handle_file_changed( SourceFileManager.SourceFile file )
    {
        /* We need to decide, whether the change occured by one of our own save
         * operations (i.e. we're still in sync) or whether the chang was done
         * by somebody else.
         *
         * To do this, we first save the fingerprint of the data as we know it:
         */
        var our_hash = file.hash;

        /* Next, we re-read the file contents, so the fingerprint gets updated.
         */
        file.get_contents();

        /* If the fingerprint changed, then we've lost sync.
         */
        if( our_hash != file.hash )
        {
            denote_conflict( file );
        }
    }

    private void remove_source_view( SourceFileManager.SourceFile file )
    {
        var source_view = source_views[ file ];
        source_views.remove( file );
        source_view.destroy();
    }

    public bool save_current_file()
    {
        if( current_file.path == null )
        {
            if( !save_current_file_as() ) return false;
        }
        else
        {
            var source_view = source_views[ current_file ];
            current_file.set_contents( source_view.buffer.text );
            session.files.set_flags( current_file.position, Session.FLAGS_MODIFIED, false );
        }

        if( current_file.has_flags( Session.FLAGS_CONFLICT ) )
        {
            resolve_conflict( current_file );
        }

        file_saved( current_file );
        return true;
    }

    public bool save_current_file_as()
    {
        bool result = false;
        FileDialog.choose_writable_file_and( get_dialog_parent(), ( path ) =>
            {
                var position = session.files.find_position( path );
                if( position < 0 )
                {
                    session.files.set_path( current_file.position, path );
                    files_view.set_active ( current_file.position );
                    result = save_current_file();
                }
                else
                {
                    // TODO: instruct to close `path` first
                    result = false;
                }
            }
        );
        return result;
    }

    public void close_current_file( bool safely = true )
    {
        if( !announce_to_close_current_file() ) return;

        var file     = current_file;
        var position = current_file.position;

        handle_files_view_changes = false;
        session.files.close( position );
        handle_files_view_changes = true;

        set_current_file_position( Utils.min( position, files_count - 1 ) );

        remove_source_view( file );
        file_closed( file );

        if( file.has_flags( Session.FLAGS_CONFLICT ) ) resolve_conflict( null );
        if( current_file == null ) search_revealer.reveal_child = false;
    }

    public bool close_all_files( bool safely = true )
    {
        if( safely && !announce_to_close_all_files() ) return false;

        handle_files_view_changes = false;
        var views = new Gee.ArrayList< SourceFileView >();
        views.add_all( get_source_views() );
        foreach( var view in views )
        {
            session.files.close( view.file.position );
            remove_source_view( view.file );
            file_closed( view.file );
        }
        handle_files_view_changes = true;

        return true;
    }

    public bool announce_to_close_current_file()
    {
        if( current_file.has_flags( Session.FLAGS_MODIFIED ) )
        {
            var dlg = new Gtk.MessageDialog(  get_dialog_parent()
                                           ,  Gtk.DialogFlags.MODAL
                                           ,  Gtk.MessageType.QUESTION
                                           ,  Gtk.ButtonsType.NONE
                                           , "This file is going to be closed." );

            dlg.add_button( "Reset Changes", 1 );
            dlg.add_button( "Cancel"       , 2 );
            dlg.add_button( "Save"         , 0 );
            Utils.apply_dialog_style( dlg );

            dlg.secondary_text = "Shall it be saved before proceeding?";
            dlg.set_default_response( 2 );
            dlg.set_transient_for( get_dialog_parent() );

            var dlg_result = dlg.run();
            dlg.destroy();

            switch( dlg_result )
            {

            case 0:
                return save_current_file();

            case 1:
                return true;

            case 2:
            default:
                return false;

            }
        }
        else return true;
    }

    public bool announce_to_close_all_files()
    {
        foreach( var view in get_source_views() )
        {
            if( view.file.has_flags( Session.FLAGS_MODIFIED ) )
            {
                set_current_file_position( view.file.position );
                if( !announce_to_close_current_file() ) return false;
            }
        }
        return true;
    }

    public int files_count
    {
        get
        {
            return session.files.count;
        }
    }

    public SourceFileManager.SourceFile get_file_at( int position )
    {
        return session.files[ position ];
    }

    private void update_files_model( int first, int count )
    {
        Gtk.TreeIter itr;
        if( first >= 0 )
        {
            /* Walk the iterator up to the first invalidated element.
             */
            files.get_iter_from_string( out itr, "%u".printf( first ) );

            for( int position = first; position < Utils.min( first + count, session.files.count ); ++position )
            {
                /* Append a row, if the iterator has moved beyond the scope of the model.
                 */
                if( !files.iter_is_valid( itr ) )
                {
                    files.insert( out itr, position );
                }

                /* Decide, which icon is to use.
                 */
                var file = session.files[ position ];
                var icon_name = "";
                if( file.has_flags( Session.FLAGS_CONFLICT ) )
                {
                    icon_name = "process-error-symbolic";
                }
                else
                if( file.has_flags( Session.FLAGS_MODIFIED ) )
                {
                    icon_name = "media-floppy-symbolic";
                }

                /* Update the current row's data.
                 */
                files.set( itr, 0, icon_name  );
                files.set( itr, 1, file.label );
                files.set( itr, 2, session.master == file ? "master" : "" );

                /* Make the iterator step forward.
                 */
                files.iter_next( ref itr );
            }
        }

        /* Now cut-off those rows, which aren't present anymore.
         */
        while( files.get_iter_from_string( out itr, "%u".printf( session.files.count ) ) )
        {
            /* Vala's documention is terribly wrong on this method. It says:
             *
             >     After being removed, itr is set to be the next valid row,
             >     or invalidated if it pointed to the last row in this.
             *
             * But it turns out, that `itr` is *always* invalid after it has
             * been passed to the `remove` method.
             */
            files.remove( itr );
        }
    }

    public void set_current_file_position( int position )
    {
        if( files_view.active != position )
        {
            files_view.active = position;
        }
        else
        {
            if( position >= 0 )
            {
                current_file = session.files[ position ];
                var source_view = source_views[ current_file ];
                stack.set_visible_child( source_view );
                source_view.grab_focus();
                if( current_file.has_flags( Session.FLAGS_CONFLICT ) )
                {
                    conflict_tool_bar.show();
                }
                else
                {
                    conflict_tool_bar.hide();
                }
                mnu_reload.set_sensitive( current_file.path != null );
                btn_master.set_active( session.master == current_file );
                search_manager.set_text_view( source_view );
            }
            else
            {
                current_file = null;
            }
            current_file_changed();
            buildable_invalidated();
        }
    }

    /**
     * References the master file, or the current file otherwise, if
     * it's been saved at some prior time. Otherwise, `null` is returned.
     */
    public SourceFileManager.SourceFile? build_input
    {
        get
        {
            var candidate = session.master != null ? session.master : current_file;
            return candidate != null && candidate.path != null ? candidate : null;
        }
    }

    /**
     * References the structure of the master file, or the current file otherwise.
     */
    public SourceStructure.Node? structure
    {
        get
        {
            var candidate = session.master != null ? session.master : current_file;
            return candidate != null ? source_views[ candidate ].structure : null;
        }
    }

    public int current_file_line
    {
        get
        {
            return current_file != null ? source_views[ current_file ].current_line : -1;
        }
        set
        {
            if( current_file != null )
            {
                source_views[ current_file ].current_line = value;
            }
        }
    }

    public bool is_buildable()
    {
        return build_input != null;
    }

    public SourceFileView get_source_view( SourceFileManager.SourceFile file )
        requires( (bool)( file in source_views.keys ) )
    {
        return source_views[ file ];
    }

    public Gee.Collection< SourceFileView > get_source_views()
    {
        return source_views.values;
    }

    public void toggle_search()
    {
        if( current_file == null ) return;
        var source_view = get_source_view( current_file );

        Gtk.Widget? focused_widget = ( get_toplevel() as Gtk.Window ).get_focus();
        bool is_search_active = focused_widget != null && Utils.is_contained_within( search_manager, focused_widget );
        if( is_search_active ) hide_search();
        else
        {
            var selection = source_view.get_selection();
            search_revealer.reveal_child = true;
            if( selection.length > 0 ) search_manager.search_entry.text = selection;
            search_manager.search_entry.select_region( 0, -1 );
            search_manager.search_entry.grab_focus();
        }
    }

    private void hide_search()
    {
        if( current_file == null ) return;
        search_manager.search_entry.text = "";
        search_revealer.reveal_child = false;
        get_source_view( current_file ).grab_focus();
    }

}

