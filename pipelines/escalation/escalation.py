import luigi

from tasks.generic import GenericTask

from tasks.icews import MothlyAggregator

class EscalationPipeline(GenericTask):
    def requires(self):
        return MothlyAggregator(pipeline=self.pipeline)

    def run(self):
        pass
