namespace Assistant
{

    public class PackagePrerequisite : AbstractPrerequisite
    {

        public string package_name;
        public string install_instructions;

        public PackagePrerequisite( Context context, string package_name, string install_instructions = "" )
        {
            base( context );
            this.package_name         = package_name;
            this.install_instructions = install_instructions;
        }

        protected override Prerequisite.Status check_status()
        {
            if( package_name.length == 0 )
            {
                warning( "Empty package name is prerequisite" );
                return Status.UNKNOWN;
            }

            return PackageAnalyzer.find_package( package_name, context.resolve_path( ".build" ) ) != null
                    ? Prerequisite.Status.FULFILLED
                    : Prerequisite.Status.VIOLATED;
        }
    
        public override string get_status_details()
        {
            if( get_status() == Prerequisite.Status.VIOLATED ) return install_instructions;
            else return "";
        }

        protected override string get_default_name()
        {
            return package_name;
        }

    }

}

