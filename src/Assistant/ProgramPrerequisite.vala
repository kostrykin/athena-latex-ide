namespace Assistant
{

    public class ProgramPrerequisite : AbstractPrerequisite
    {

        public string executable_name;
        public string install_instructions;

        public ProgramPrerequisite( Context context, string executable_name, string install_instructions = "" )
        {
            base( context );
            this.executable_name      = executable_name;
            this.install_instructions = install_instructions;
        }

        protected override Prerequisite.Status check_status()
        {
            if( executable_name.length == 0 )
            {
                warning( "Empty executable name is prerequisite" );
                return Prerequisite.Status.UNKNOWN;
            }
            return Environment.find_program_in_path( executable_name ) != null ? Prerequisite.Status.FULFILLED : Prerequisite.Status.VIOLATED;
        }
    
        public override string get_status_details()
        {
            if( get_status() == Prerequisite.Status.VIOLATED ) return install_instructions;
            else return "";
        }

        protected override string get_default_name()
        {
            return executable_name;
        }

    }

}

