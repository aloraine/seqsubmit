process EUKCC_FOLDER {
    tag "${meta.id}"
    label 'process_medium'
    label 'process_long'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/eukcc:2.2.0--050b7bea3f69b4a8':
        'community.wave.seqera.io/library/eukcc:2.2.0--212dfaba26f5edd2' }"

    input:
    tuple val(meta), path(links), path(bins, stageAs: 'bins/*')
    tuple val(meta2), path(db)

    output:
    tuple val(meta), path("${prefix}_results/merged_bins"), emit: merged_bins
    tuple val(meta), path("${prefix}.eukcc.csv")          , emit: csv
    tuple val(meta), path("${prefix}.merged_bins.csv")    , emit: merged_csv
    tuple val("${task.process}"), val('eukcc'), eval('eukcc -v 2>&1 | grep -oE "[0-9]+\\.[0-9]+\\.[0-9]+" | head -n1'), emit: versions_eukcc, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args      = task.ext.args ?: ''
    prefix        = task.ext.prefix ?: "${meta.id}"
    def links_arg = links ? "--links ${links}" : ''
    """
    mkdir -p bins ${prefix}_results/merged_bins

    if [ -z "\$(ls -A bins)" ]; then
        echo "No bins in input" >&2
        touch ${prefix}.eukcc.csv ${prefix}.merged_bins.csv
    else
        set +e
        eukcc folder \\
            ${args} \\
            --threads ${task.cpus} \\
            ${links_arg} \\
            --db ${db} \\
            --out ${prefix}_results \\
            --prefix ${prefix}_merged. \\
            bins
        exit_code=\$?
        set -e

        case \$exit_code in
            0)
                mv ${prefix}_results/eukcc.csv ${prefix}.eukcc.csv
                mv ${prefix}_results/merged_bins.csv ${prefix}.merged_bins.csv
                ;;
            204)
                # EukCC exits with 204 when MetaEuk predicts zero proteins
                echo "MetaEuk returned zero proteins" >&2
                touch ${prefix}.eukcc.csv ${prefix}.merged_bins.csv
                ;;
            *)
                exit \$exit_code
                ;;
        esac
    fi
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_results/merged_bins
    touch ${prefix}.eukcc.csv ${prefix}.merged_bins.csv
    """
}
