import os

from tasks.generic import GenericTask
from tasks.httpdownload import HttpDownload
from utils.dataverse import DataverseAPI

class DatasetDownloader(GenericTask):
    DATASET_FOLDER = os.path.join(os.getcwd(), "datasets/icews")

    def run(self):
        download_queue = list()

        dataverse = DataverseAPI(config_path=os.path.dirname(__file__))
        contents = dataverse.request("dataverses/icews/contents")

        for data in filter(lambda d: d['type']=='dataset', contents['data']):
            dataset_id = str(data['id'])
            dataset = dataverse.request("datasets", dataset_id)

            for f in dataset['data']['latestVersion']['files']:
                file_id = str(f['datafile']['id'])
                url = dataverse.url("access/datafile", file_id)

                filename = f['datafile']['name']
                checksum = f['datafile']['md5']
                target = os.path.join(self.DATASET_FOLDER, dataset_id, filename)

                download_queue.append(HttpDownload(url, checksum, target))

        # now try to download the dataset
        yield(download_queue)


class DatasetExtractor(GenericTask):
    def requires(self):
        return DatasetDownloader(pipeline=self.pipeline)

class EventAgentMerger(GenericTask):
    def requires(self):
        return DatasetExtractor(pipeline=self.pipeline)

class MothlyAggregator(GenericTask):
    def requires(self):
        return EventAgentMerger(pipeline=self.pipeline)

