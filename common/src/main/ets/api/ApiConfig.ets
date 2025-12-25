export interface RequestUrl {
  GenerateExamPaper: string,
  GetBankQuestion:  string,
  GetJudgeQuestion: string,
  GetManyQuestion: string,
  Search:  string,
  AddLike: string,
  AddWrong: string,
  ListLike: string,
  ListWrong: string,
  SearchCollect: string,
  SearchDetail: string,
  DeleteWrong: string,
  WrongDetail: string
}

export class ApiConfig {
  static readonly requestUrl: RequestUrl = {
    GenerateExamPaper: 'topic.rolldata',
    GetBankQuestion: 'topic.topiclist',
    GetJudgeQuestion: 'topic.judgelist',
    GetManyQuestion: 'topic.manylist',
    Search: 'topic.seachdata',
    AddLike: 'topic.addcollect',
    AddWrong: 'topic.add_wrong',
    ListLike: 'topic.collectlist',
    ListWrong: 'topic.wrong_list',
    SearchCollect: 'topic.seach_collect',
    SearchDetail: 'topic.collectdata',
    DeleteWrong: 'topic.delete_wrong',
    WrongDetail: 'topic.wrong_data'
  }
}