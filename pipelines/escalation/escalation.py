from tasks.pipeline import Pipeline
from tasks.icews import MothlyAggregator

class EscalationPipeline(Pipeline):
    def requires(self):
        return MothlyAggregator(pipeline=self)

    def run(self):
        pass
