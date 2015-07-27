import os
import zipfile

from tasks.generic import GenericTask
from tasks.httpdownload import HttpDownload
from tasks.zip import ZipFileExtractor

import utils.dataverse
import utils.md5

class DatasetDownloader(GenericTask):
    DATASET_FOLDER = os.path.join(os.getcwd(), "datasets/icews")

    def requires(self):
        queue = list()

        dataverse = utils.dataverse.DataverseAPI(config_path=os.path.dirname(__file__))
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

                if os.path.isfile(target) and utils.md5.file_checksum(target, hex=True) == checksum:
                    if zipfile.is_zipfile(target):
                        queue.append(ZipFileExtractor(pipeline=self.pipeline, filename=target))
                else:
                    self.logger.debug("updating download_queue %s" % target)
                    queue.append(HttpDownload(url, checksum, target))

        # now try to download the dataset
        yield queue

class EventAgentMerger(GenericTask):
    def requires(self):
        return DatasetDownloader(pipeline=self.pipeline)

class MothlyAggregator(GenericTask):
    def requires(self):
        return EventAgentMerger(pipeline=self.pipeline)

