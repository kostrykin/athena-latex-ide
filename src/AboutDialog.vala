public class AboutDialog : Gtk.Dialog
{

    private Gtk.Stack screens = new Gtk.Stack();

    public AboutDialog( Gtk.Window? parent )
    {
        var screen_switcher = new Gtk.StackSwitcher();
        screen_switcher.stack = screens;
        screen_switcher.halign = Gtk.Align.CENTER;

        var container = ( (Gtk.Box) get_content_area() );
        container.pack_start( screen_switcher, false, false );
        container.pack_end  ( screens        , true , true  );

        var athena_container = new Gtk.Box( Gtk.Orientation.VERTICAL, 0 );
        var athena_screen    = populate_athena_screen( athena_container );
        screens.add_titled( athena_container, "athena", "Athena" );

        var synctex_container = new Gtk.Box( Gtk.Orientation.VERTICAL, 0 );
        populate_synctex_screen( synctex_container );
        screens.add_titled( synctex_container, "synctex", "SyncTeX" );

        var scratch_container = new Gtk.Box( Gtk.Orientation.VERTICAL, 0 );
        populate_scratch_screen( scratch_container );
        screens.add_titled( scratch_container, "scratch", "Scratch" );

        var granite_container = new Gtk.Box( Gtk.Orientation.VERTICAL, 0 );
        populate_granite_screen( granite_container );
        screens.add_titled( granite_container, "granite", "Granite" );

        var buttons = new AboutDialogButtons( athena_screen );

        buttons.help      = Athena.instance.help_url;
        buttons.translate = Athena.instance.translate_url;
        buttons.bug       = Athena.instance.bug_url;

        Gtk.ButtonBox action_area = (Gtk.ButtonBox) get_action_area();
        buttons.put_into( action_area );
        set_default_response( Gtk.ResponseType.CANCEL );

        var close_button = add_button( "Close", Gtk.ResponseType.CLOSE );
        close_button.grab_focus();

        Utils.apply_dialog_style( this );
        set_transient_for( parent );
        has_resize_grip = false;
        height_request = 400;
        width_request = 700;
        show_all();
    }

    private Granite.GtkPatch.AboutDialog populate_athena_screen( Gtk.Container container )
    {
        var screen = new Granite.GtkPatch.AboutDialog();

        screen.program_name       = Athena.instance.program_name;
        screen.version            = Athena.instance.build_version;
        screen.logo_icon_name     = Athena.instance.app_icon;
        screen.comments           = Athena.instance.about_comments;
        screen.copyright          = "%s %s Developers".printf( Athena.instance.app_years, Athena.instance.program_name );
        screen.website            = Athena.instance.main_url;
        screen.website_label      = Athena.instance.main_url;
        screen.authors            = Athena.instance.about_authors;
        screen.documenters        = Athena.instance.about_documenters;
        screen.artists            = Athena.instance.about_artists;
        screen.translator_credits = Athena.instance.about_translators;
        screen.license            = Athena.instance.about_license;
        screen.license_type       = Athena.instance.about_license_type;

        screen.get_content_area().reparent( container );
        screen.get_content_area().vexpand = true;
        screen.get_content_area().hexpand = true;

        screen.get_action_area().no_show_all = true;
        screen.get_action_area().hide();

        return screen;
    }

    private void populate_synctex_screen( Gtk.Container container )
    {
        var screen = new Granite.GtkPatch.AboutDialog();

        screen.program_name       = "SyncTeX";
        screen.version            = "1.16";
        screen.comments           =
"""The Synchronization TeXnology named SyncTeX is a new feature of
recent TeX engines designed by Jerome Laurens. It allows to
synchronize between input and output, which means to navigate
from the source document to the typeset material and vice versa.""";
        screen.copyright          = "2008-2011 Jerome Laurens";
        screen.website            = "http://itexmac.sourceforge.net/SyncTeX.html";
        screen.website_label      = screen.website;
        screen.authors            = { "Jerome Laurens <jerome.laurens@u-bourgogne.fr>", null };
        screen.license            =
"""Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE

Except as contained in this notice, the name of the copyright holder  
shall not be used in advertising or otherwise to promote the sale,  
use or other dealings in this Software without prior written  
authorization from the copyright holder.""";

        screen.get_content_area().reparent( container );
        screen.get_content_area().vexpand = true;
        screen.get_content_area().hexpand = true;

        screen.get_action_area().no_show_all = true;
        screen.get_action_area().hide();
    }

    private void populate_scratch_screen( Gtk.Container container )
    {
        var screen = new Granite.GtkPatch.AboutDialog();

        screen.program_name       = "Scratch Text Editor";
        screen.version            = "2.2.1";
        screen.comments           =
"""The text editor of elementary OS.

Athena uses an adapted version of following files:
• SearchManager.vala""";
        screen.copyright          = "2011-2013 Scratch Developers";
        screen.website            = "https://launchpad.net/scratch";
        screen.website_label      = screen.website;
        screen.license_type       = Gtk.License.GPL_3_0;

        screen.get_content_area().reparent( container );
        screen.get_content_area().vexpand = true;
        screen.get_content_area().hexpand = true;

        screen.get_action_area().no_show_all = true;
        screen.get_action_area().hide();
    }

    private void populate_granite_screen( Gtk.Container container )
    {
        var screen = new Granite.GtkPatch.AboutDialog();

        screen.program_name       = "Granite";
        screen.version            = "0.3.1";
        screen.comments           =
"""A development library for elementary development.

Athena uses the library and an adapted version of following files:
• AboutDialog.vala
• SimpleCommand.vala""";
        screen.copyright          = "2011-2013 Granite Developers";
        screen.website            = "https://launchpad.net/granite";
        screen.website_label      = screen.website;
        screen.authors            = { "Adam Davies <adam.davies@outlook.com>"
                                    , "Adrien Plazas <kekun.plazas@laposte.net>"
                                    , "ammonkey <am.monkeyd@gmail.com>"
                                    , "Avi Romanoff <aviromanoff@gmail.com>"
                                    , "Cody Garver"
                                    , "Corentin Noël"
                                    , "Daniel Foré <daniel@elementaryos.org>"
                                    , "Devid Antonio Filoni aka devfil"
                                    , "Elias aka eyelash"
                                    , "Lucas Baudin <xapantu@gmail.com>"
                                    , "Marcus Lundgren"
                                    , "Mario Guerriero <mario@elementaryos.org>"
                                    , "Mathijs Henquet"
                                    , "Maxwell Barvian <mbarvian@gmail.com>"
                                    , "Rico Tzschichholz"
                                    , "Robert Dyer"
                                    , "Tom Beckmann"
                                    , "Tristan Cormier"
                                    , "ttosttos"
                                    , "Victor Eduardo <victoreduardm@gmail.com>"
                                    , null };
        screen.license_type       = Gtk.License.GPL_3_0;

        screen.get_content_area().reparent( container );
        screen.get_content_area().vexpand = true;
        screen.get_content_area().hexpand = true;

        screen.get_action_area().no_show_all = true;
        screen.get_action_area().hide();
    }

}

