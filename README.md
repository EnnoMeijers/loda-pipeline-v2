# Workflow loda-pipelines

## Directory structure

```md
loda-pipeline/
├── europeana-tools                         * tool for conversion to EDM 
├── jena-fuseki-docker-5.6.0                * used as local triplestore
└── pipelines
    ├── dataset 1
    |   ├── environment                     * main variables defining the dataset
    |   ├── ld-workbench
    |   |   ├── data                        * created by ld-workbench 
    |   |   ├── queries                     * manually created sparql queries that define the mapping
    |   |   └── config.yml                  * configuration file for the mapping process
    |   |
    |   └── fuseki
    |       ├── config.ttl
    |       └── <input file>
    |
    ├── dataset 2 
    |
    ├── dataset n
    |
    ├── scripts                             * scripts as building blocks for the pipeline
    | 
    └── generic
        ├── queries                         * templates for the mapping queries
        |   ├── iterator-stage-1.rq
        |   └── generator-stage-1.rq
        ├── environment                     * template for the pipeline configuration
        ├── fuseki-config.ttl               * template for the fuseki configuration
        ├── ld-workbench-config.yml         * template for the ld-workbench configuration
        ├── distinct.rq                     * query used for deduplication
        └── edm.ttl                         * shape file for EDM validation
```

Starting point for the pipeline configuration is the `pipelines` directory.
Each pipeline is created as a separate "dataset" directory within `pipelines`.

## 1. Preparation of a new dataset in the pipeline
In order to add a new dataset to the pipeline a number of steps must be performed. These steps are the initialization of the dataset, setting some environment variables, automatically create configuration scripts and edit the sparql queries for the transformation. These steps are described in detail below.

### Initialize a new dataset
This step creates an new entry for the pipeline. Each dataset transformation is regarded as a separate pipeline. The script `init-dataset` takes a dataset name as input and creates an empty structure for this pipeline in within the `pipelines` directory with the lowercase version of the dataset name including an empty `environment` file. 

```
$ cd pipelines
$ scripts/init-dataset.sh <dataset>
```

The result should be something like this:

```
initialize pipeline for 'amateurfilm'
Creating <dataset>
Creating subdirectory for 'ld-workbench'
Creating subdirectory for 'fuseki'
Installing default query files
Installing 'environment' file
Set DATASET name to <dataset> in <dataset>/environoment
Init proces finished - to proceed set the correct variables in the 'environment' file in <dataset>
```

### Edit the enivronment file
Edit the `environment` file in newly created dataset directory. Set the value for `SOURCE_URL` for downloading the dataset or place a dataset file in the current directory and set `SOURCE_FILE` to name of the file. If the `SOURCE_URL` is set the `SOURCE_FILE` variable will be set automaticly (see next step). The variable `PRODUCTION=0` is used for signalling that this dataset is ready for production. Setting the value to `1` will make this dataset part of the complete pipeline and the processing will be run periodically. Leave the value at `0` while testing the new setup for this datasets. The seperate steps in the pipeline can be run manually, see below. 

TODO: use the NDE Datasetregister to download the data

### Set up the pipeline configuration 
The next step is automatically creating the config files for Fuseki and LDWorkbench based on the variables that have been set in the previous step. This is done by calling the `configure.sh` script from the newly created directory for the `dataset`. Note that all other scripts are run from this directory too! 

```
$ cd <dataset>      # if necessary
$ ../scripts/configure.sh
```

The `configure.sh` script reads the environment variables. If the `SOURCE_URL` is given an automatic download of the dataset is executed and if succesful, the `SOURC_FILE` variable is set to point to the download file in tha dataset directory.  

### Edit the sparql queries used for the mapping
Before the transformation can be run the mapping definition must be defined. SPARQL CONSTRUCT queries are used to perform the linked data to linked data transformation. For robust processing of the queries and the results the [LD-Workbench](https://github.com/netwerk-digitaal-erfgoed/ld-workbench) tool is used. 

For this tool a so called generator query must be defined used for selecting the resource that are in scope for the transformation. See [interator-stage-1.rq](pipelines/generic/iterator-stage-1.rq) for the default version for this query. The actualy mapping for each of the resource is defined using a CONSTRUCT query, the so called generator query. See [generator-stage-1.rq](pipelines/generic/generator-stage-1.rq) for the default version. 

Both queries are installed in the `<dataset>/ld-workbench` subdirectory. Adjust these queries to define the specific conversion for this dataset. 

Tip: Writing the generator query can be hard. You can start a local sparql endpoint (see next step) and use Yasgui or another tool to create the query interactivly. When finished make sure that the subject `(?s)` is replaced by the iterator variable `$this`.


### 2. Testing the pipeline
The pipeline is now configured to create the datasets acoording to configuration steps described above. Before adding the new dataset to the production pipeline all it should be tested manualy. The section below describes a complete cycle. When satisfied with the results of all the steps the dataset can be added to the production pipeline. See belowd for more information. 

### Starting the sparql server
The next step is starting the local sparql server with using the dataset defined in the `environment` file. The script will start the server as a background task.

```
$ cd <dataset>      # if necessary
$ ../scritps/start-sparql-server.sh <dataset>
```

The output should be similar to:
```
Starting the SPARQL server with for <dataset>...
[+] Running 1/1
 ✔ Container pipelines-fuseki-1  Started
 ```

The SPARQL endpoint should now be available at `http://localhost:3030/<dataset>/sparql`. Visiting this URL in the browser should show the following message:
`Service Description: /<dataset>/sparql`

In case of problems see the logfile in the fuseki/logs map for details.


### Running the mapping 
All is set now to do the actual transformation of the data. Make sure the starting point is the `<dataset>` directory.

```
$ cd <dataset>      # if necessary
$ ../scritps/run-mapping.sh <dataset>
```

This should result something similar to the output below:

```
Transform the data for <dataset> using LD-workbench...
Welcome to LD Workbench version 2.8.1
▶ Starting pipeline “<dataset>”
✔ Validating pipeline
✔ Stage “Stage 1 - Schema2EDM” resulted in 66,166 statements in 2,985 iterations (took 21.7s)
✔ Writing results to destination pipelines/<dataset>.nt
✔ Your pipeline “<dataset>” was completed in 22s using 137 MB of memory
```

When succesfully completed the resulting output file is moved to the root of the `<dataset>` directory and hasm the name `<dataset>.nt`.

### Stopping the sparql endpoint
The SPARQL-endpoint is no longer needed, so it can be stopped:

```
$ cd <dataset>      # if necessary
$ ../scritps/stop-sparql-server.sh <dataset>
``` 

### Running the EDM conversion
Although the resulting dataset contains usuable EDM linked data some additional steps must be taken to make this dataset ready for delivery to ingestion pipeline of Europeana. 

The `convert-to-edm.sh` script performs the folling steps:

- deduplicate the LD-Workbench output
- validate the data against an EDM shape file
- convert the data to an RDF/XML serialization
- rewrite the RDF/XML serialization to XML 
- zip the result

So to perform these step run the following command:
```
$ cd <dataset>      # if necessary
$ ../scritps/convert-to-edm.sh <dataset>
```

Check the `validate-report.txt` in the `<dataset>` directory for any detected problems and adjust the generator query if nessecary and rerun the mapping and convert steps. 

*Note: the deduplication is a performed to make sure that there are no duplicate triples in the resultset. This step also garantees that the edm:isShowBy only has one value for each resource, when more values are generated in the mapping process a random choice is made. See the [distinct.rq](./pipelines/generic/distinct.rq) query for more details.*


### Create a dataset description
The result of the transformation is a dataset that can be published and registered in the NDE-Datasetregister. In order to do so a dataset description according to the NDE requirements must be created. The dataset description requires a number of static data fields that must be set through the `environment` file. See the section with the `DATASET_DESCRIPTION` for the variables that must be set. See the [NDE Requirements](https://docs.nde.nl/requirements-datasets/) for more details about the different variables and the allowed values. 

After setting the variables the dataset description can be created with the following script:

```
$ cd <dataset>      # if necessary
$ ../scritps/make_dataset_description.sh <dataset>
``` 

This shoud result in a file called `datasetdescription.ttl` in the `<dataset>` that can be used to register the new dataset to the NDE-Datasetregister. In the file `validate-report-datasetdescription.txt` the result of the validation is given. See the requirements doc mentioned above for more information about eventual errors and warnings. 


## Run the complete pipeline
After a succesful result for all steps mentioned above the dataset is ready to be added to the pipline to be run automatically. Change the `PRODUCTION` variable in the `environment` file to `1`. And either go back to the `pipelines` directory and run of the `run-all.sh` script with the `<dataset>` as parameter to process only this dataset or without a parameter to run the pipeline for all the datasets.

```
$ cd pipelines      # if necessary
$ scritps/run-all.sh [ <dataset> ]   # optional parameter
``` 

