namespace Assistant
{

    public class MetropolisPresentation : SimpleProjectType
    {

        private static DownloadablePrerequisite create_fira_font_requisite( Context context, string name, string filename )
        {
            var requisite = new DownloadablePrerequisite
                    ( context
                    , filename
                    , @"https://github.com/mozilla/Fira/blob/master/ttf/$filename?raw=true"
                    , "~/.fonts/FiraSans/" );

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

        private void add_prerequisites( Context context )
        {
            prerequisites.add_prerequisite( new ProgramPrerequisite( context, "lualatex", "Please run: sudo apt-get install texlive-luatex" ) );

            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Mono", "FiraMono-Regular.ttf" ) );
            prerequisites.add_prerequisite( create_fira_font_requisite( context, "Fira Typeface Sans", "FiraSans-Regular.ttf" ) );

            prerequisites.add_prerequisite( create_sty_requisite( context, "beamercolorthememetropolis.sty", "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamercolorthememetropolis.sty" ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerfontthememetropolis.sty" , "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerfontthememetropolis.sty"  ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerinnerthememetropolis.sty", "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerinnerthememetropolis.sty" ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerouterthememetropolis.sty", "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerouterthememetropolis.sty" ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "beamerthememetropolis.sty"     , "https://dl.dropboxusercontent.com/u/8265828/metropolis/beamerthememetropolis.sty"      ) );
            prerequisites.add_prerequisite( create_sty_requisite( context, "pgfplotsthemetol.sty"          , "https://dl.dropboxusercontent.com/u/8265828/metropolis/pgfplotsthemetol.sty"           ) );
        }

        private void add_setup_fields()
        {
            setup.append_entry( SETUP_AUTHOR   , "Author:"   , new FormValidators.NonEmpty() );
            setup.append_entry( SETUP_DATE     , "Date:"     , null );
            setup.append_entry( SETUP_TITLE    , "Title:"    , new FormValidators.NonEmpty() );
            setup.append_entry( SETUP_SUB_TITLE, "Sub-title:", null );
            setup.append_entry( SETUP_INSTITUTE, "Institute:", null );
        }

    }

}

