//生成试卷
export interface TopicRollDataParams {
  sign: string;
  type: string;
  num: number;
  topicnum: number;
  manynum: number;
  judgenum: number;
}
export interface TopicData {
  bankdata: BankData,
  judgedata: JudgeData,
  manydata: ManyData
}
export interface TopicRollDataResponse {
  data: TopicData,
  issucc: boolean,
  msg: string,
  code: string
}

//获取单选、判断题、多选
export interface getDataParams {
  sign: string;
  type: string;
  num: number
}

//题目搜索
export interface QuestionSearchParams {
  sign: string,
  cate: string,
  type: string,
  keyword: string,
  pageindex: string,
  pagesize: string
}


//单选、多选、判断响应,包括搜索
export interface QuestionDataResponse {
  data: QuestionItem[],
  issucc: boolean,
  msg: string,
  code: string
}


export interface QuestionItem {
  id: number,
  type: string,
  title: string,
  option1: string,
  option2: string,
  option3?: string,
  option4?: string,
  correct: string,
  analysis: string,
  source: string,
  isLike?: boolean
}
export interface BankData {
  type: string,
  banklist: QuestionItem[]
}
export interface JudgeData {
  type: string,
  judgelist: QuestionItem[]
}
export interface ManyData {
  type: string,
  manylist: QuestionItem[]
}


//收藏、错题添加
export interface AddParams {
  sign: string,
  userid: number,
  cate: string,
  problemid: string
}
//收藏、错题添加响应，删除错题响应
export interface AddResponse {
  issucc: boolean,
  msg: string,
  code: string
}

//收藏列表、错题列表参数,收藏搜索
export interface ListParams {
  sign: string,
  userid: string,
  keyword?: string
}

//收藏列表、错题列表响应
export interface ListResponse {
  data: ListItem[],
  issucc: boolean,
  msg: string,
  code: string
}

export interface ListItem {
  id: number,
  problemId: number,
  userid: number
  cate: string,
  title: string,
}

//收藏详情、错题详情参数,删除错题
export interface DetailsParam {
  sign: string,
  id: number
}
export interface DetailsResponse {
  data: QuestionItem,
  issucc: boolean,
  msg: string,
  code: string
}



