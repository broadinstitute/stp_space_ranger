version 1.0
task space_ranger {

    command <<<

        spaceranger testrun --id=tiny

    >>>

    runtime {
        docker: "jishar7/space_ranger@sha256:538f88a9f9cfe997b0bf7480fea05a724267c1f13ce1c406e65e16bdcbc8db04"
        memory: "100GB"
        preemptible: 2
        disks: "local-disk 200 HDD"
    }

}