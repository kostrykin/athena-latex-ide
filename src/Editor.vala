class Editor : Gtk.Box
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

    private Gtk.ListStore    files      = new Gtk.ListStore( 3, typeof( string ), typeof( string ), typeof( string ) );
    private Gtk.Stack        stack      = new Gtk.Stack(); 
    private Gtk.Toolbar      toolbar    = new Gtk.Toolbar();
    private Gtk.MenuItem     mnu_reload = new Gtk.MenuItem.with_label( "Reload" );
    private Gtk.ToggleButton btn_master = new Gtk.ToggleButton.with_label( "Master" );
    private Gtk.ComboBox     files_view;

    private Gtk.InfoBar conflict_info_bar = new Gtk.InfoBar();
    private Gtk.InfoBar conflict_tool_bar = new Gtk.InfoBar();

    private Gee.Map< FileManager.File, SourceView > source_views = new Gee.HashMap< FileManager.File, SourceView >();

    public Session session { private set; public get; default = new Session(); }
    public FileManager.File? current_file { private set; public get; }

    public signal void file_opened( FileManager.File file );
    public signal void file_closed( FileManager.File file );
    public signal void current_file_changed();
    public signal void buildable_invalidated();

    private bool handle_files_view_changes = true;

    public Editor()
    {
        Object( orientation: Gtk.Orientation.VERTICAL, spacing: 0 );
        this.setup_infobars();
        this.pack_start( conflict_info_bar, false );
        this.setup_toolbar();
        this.pack_end( stack, true, true );
        this.pack_end( conflict_tool_bar, false );
        this.stack.show();

        this.session.files.invalidated.connect( update_files_model );
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

    private void denote_conflict( FileManager.File file )
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

    private void resolve_conflict( FileManager.File? file )
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
        btn_new.show();

        var btn_open = new Gtk.ToolButton( ICON_OPEN, null );
        toolbar.add( btn_open );
        btn_open.clicked.connect( open_file );
        btn_open.show();

        var btn_save = new Gtk.ToolButton( ICON_SAVE, null );
        toolbar.add( btn_save );
        btn_save.clicked.connect( save_current_file );
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
        btn_close.clicked.connect( close_current_file );
        btn_close_toolitem.add( btn_close );

        toolbar.add( new Gtk.SeparatorToolItem() );
        toolbar.add( files_view_toolitem );
        toolbar.add( btn_close_toolitem );
        toolbar.add( new Gtk.SeparatorToolItem() );

        var btn_master_toolitem = new Gtk.ToolItem();
        btn_master_toolitem.add( btn_master );
        btn_master.can_focus = false;
        btn_master.tooltip_text = "Always build this file";
        btn_master.toggled.connect( set_current_file_master );
        toolbar.add( btn_master_toolitem );

        var mnu_save_as = new Gtk.MenuItem.with_label( "Save as..." );
        mnu_save_as.activate.connect( save_current_file_as );
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

    private void open_file()
    {
        FileDialog.choose_readable_file_and( ( path ) => { open_file_from( path ); } );
    }

    public FileManager.File open_file_from( string? path )
    {
        var position = path != null ? session.files.find_position( path ) : -1;
        if( position < 0 )
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

    public void set_current_file_master()
    {
        if( btn_master.get_active() )
        {
            if( session.master != current_file )
            {
                if( session.master != null )
                {
                    var position = session.master.position;
                    session.master = null;
                    update_files_model( position, 1 );
                }
                session.master = current_file;
                update_files_model( current_file.position, 1 );
            }
        }
        else
        {
            if( session.master == current_file )
            {
                session.master = null;
                update_files_model( current_file.position, 1 );
            }
        }
        buildable_invalidated();
    }

    private void add_source_view( FileManager.File file )
    {
        var source_view = new SourceView( file );
        source_view.buffer.text = file.get_contents();
        source_view.buffer.changed.connect( () =>
            {
                session.files.set_flags( file.position, Session.FLAGS_MODIFIED );
            }
        );
        file.changed.connect( () =>
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
        );
        stack.add( source_view );
        source_views[ file ] = source_view;
        source_view.show_all();
    }

    private void remove_source_view( FileManager.File file )
    {
        var source_view = source_views[ file ];
        stack.remove( source_view );
        source_views.remove( file );
    }

    public void save_current_file()
    {
        if( current_file.path == null )
        {
            save_current_file_as();
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
    }

    public void save_current_file_as()
    {
        FileDialog.choose_writable_file_and( ( path ) =>
            {
                var position = session.files.find_position( path );
                if( position < 0 )
                {
                    session.files.set_path( current_file.position, path );
                    files_view.set_active ( current_file.position );
                    save_current_file();
                }
                else
                {
                    // TODO: instruct to close `path` first
                }
            }
        );
    }

    public void close_current_file()
    {
        var file     = current_file;
        var position = current_file.position;

        handle_files_view_changes = false;
        session.files.close( position );
        handle_files_view_changes = true;

        set_current_file_position( Utils.min( position, files_count - 1 ) );

        remove_source_view( file );
        file_closed( file );

        if( file.has_flags( Session.FLAGS_CONFLICT ) )
        {
            resolve_conflict( null );
        }
    }

    public int files_count
    {
        get
        {
            return session.files.count;
        }
    }

    public FileManager.File get_file_at( int position )
    {
        return session.files[ position ];
    }

    private void update_files_model( int first, int count )
    {
        /* Walk the iterator up to the first invalidated element.
         */
        Gtk.TreeIter itr;
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
            }
            else
            {
                current_file = null;
            }
            current_file_changed();
            buildable_invalidated();
        }
    }

    public FileManager.File? build_input
    {
        get
        {
            var candidate = session.master != null ? session.master : current_file;
            return candidate != null && candidate.path != null ? candidate : null;
        }
    }

    public int current_file_line
    {
        get
        {
            return current_file != null ? source_views[ current_file ].current_line : -1;
        }
    }

    public bool is_buildable()
    {
        return build_input != null;
    }

}

