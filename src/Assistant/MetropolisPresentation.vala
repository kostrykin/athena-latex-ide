namespace Assistant
{

    public class MetropolisPresentation : SimpleProjectType
    {

        private static DownloadablePrerequisite create_fira_font_requisite( Context context, string name, string filename )
        {
            var requisite = new DownloadablePrerequisite
                    ( context
                    , @"$filename.ttf"
                    , @"https://github.com/mozilla/Fira/blob/master/ttf/$filename.ttf?raw=true"
                    , "~/.fonts/Fira/" );

            requisite.add_font_search_directories();
            requisite.name_override = name;
            return requisite;
        }

        private static DownloadablePrerequisite create_sty_requisite( Context context, string filename, string url )
        {
            var requisite = new DownloadablePrerequisite( context, filename, url, "." );
            requisite.add_latex_package_search_directories();
            return requisite;
        }

        private PrerequisitesPage prerequisites = new PrerequisitesPage();
        private FormPage          setup         = new FormPage( "Configuration" );

        private static const string SETUP_AUTHOR    = "author";
        private static const string SETUP_DATE      = "date";
        private static const string SETUP_TITLE     = "title";
        private static const string SETUP_SUB_TITLE = "sub-title";
        private static const string SETUP_INSTITUTE = "institute";

        public MetropolisPresentation()
        {
            base( "Metropolis Presentation", "Metropolis is a modern LaTeX Beamer theme by Matthias Vogelgesang, that uses Mozilla's Fira typeface." );
            add_page( prerequisites );
            add_page( setup );
        }

        public override void prepare( Context context )
        {
            base.prepare( context );
            Idle.add( () =>
                {
                    add_prerequisites( context );
                    add_setup_fields();
                    return false;
                }
            );
        }

        private static const string XELATEX_INSTALL_INSTRUCTIONS = "Please run: sudo apt-get install texlive-xetex";

        private void add_prerequisites( Context context )
        {
            prerequisites.add_prerequisite( new ProgramPrerequisite( context, "xelatex", XELATEX_INSTALL_INSTRUCTIONS ) );
            prerequisites.add_prerequisite( new PackagePrerequisite( context, "eu2enc" , XELATEX_INSTALL_INSTRUCTIONS ) );

            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Mono"             , "FiraMono-Regular"     ) );
            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Mono-Bold"        , "FiraMono-Bold"        ) );
            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Sans"             , "FiraSans-Regular"     ) );
            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Sans-Light"       , "FiraSans-Light"       ) );
            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Sans-Light-Italic", "FiraSans-LightItalic" ) );
            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Sans-Italic"      , "FiraSans-Italic"      ) );

            prerequisites.add_prerequisite( create_sty_requisite( context, "beamercolorthememetropolis.sty", "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamercolorthememetropolis.sty" ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerfontthememetropolis.sty" , "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerfontthememetropolis.sty"  ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerinnerthememetropolis.sty", "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerinnerthememetropolis.sty" ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerouterthememetropolis.sty", "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerouterthememetropolis.sty" ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerthememetropolis.sty"     , "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerthememetropolis.sty"      ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "pgfplotsthemetol.sty"          , "https://dl.dropboxusercontent.com/u/8265828/metropolis/pgfplotsthemetol.sty"           ) );
        }

        private void add_setup_fields()
        {
            setup.append_entry    ( SETUP_AUTHOR   , "Author:"    , new FormValidators.NonEmpty(), Environment.get_real_name() );
            setup.append_entry    ( SETUP_TITLE    , "Title:"     , new FormValidators.NonEmpty() );
            setup.append_entry    ( SETUP_SUB_TITLE, "Sub-title:" , null );
            setup.append_entry    ( SETUP_DATE     , "Fixed date:", null );
            setup.append_text_view( SETUP_INSTITUTE, "Institute:" , null );
        }

        public override void create( MainWindow main_window )
        {
            string? asset_path = Utils.find_asset( "metropolis.tex" );
            assert( asset_path != null );
            var asset_file = File.new_for_path( asset_path );
            var asset_contents = Utils.read_text_file( asset_file );
            asset_contents = asset_contents.replace( "%% HEADER %%\n", get_header() ) + "\n";

            string tex_path = Path.build_path( Path.DIR_SEPARATOR_S, context.get_project_dir_path(), "slides.tex" );
            var tex_file = File.new_for_path( tex_path );
            tex_file.replace_contents( asset_contents.data, null, false, FileCreateFlags.NONE, null, null );

            main_window.editor.open_file_from( tex_path );
            main_window.request_build_type( BuildManager.FLAGS_XE_LATEX );
        }

        private string get_header()
        {
            var header = "\\author{%s}\n\\title{%s}\n".printf( setup[ SETUP_AUTHOR ], setup[ SETUP_TITLE  ] );

            var date      = setup[ SETUP_DATE      ]; 
            var sub_title = setup[ SETUP_SUB_TITLE ]; 
            var institute = setup[ SETUP_INSTITUTE ]; 

            if(      date.length > 0 ) header += "\\date{%s}\n"     .printf( date );
            if( sub_title.length > 0 ) header += "\\subtitle{%s}\n" .printf( sub_title );
            if( institute.length > 0 ) header += "\\institute{%s}\n".printf( institute );

            return header;
        }

    }

}

