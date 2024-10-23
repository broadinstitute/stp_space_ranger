version 1.0

import "space_ranger.wdl" as SPACE_RANGER

workflow MAIN_WORKFLOW {

    call SPACE_RANGER.space_ranger as space_ranger {}
    
}
