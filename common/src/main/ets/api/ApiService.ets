import { instance } from "../utils/AxiosRequest";
import { ApiConfig } from "./ApiConfig";
import {
  AddParams,
  AddResponse,
  DetailsParam,
  DetailsResponse,
  getDataParams,
  ListParams,
  ListResponse,
  QuestionDataResponse,
  QuestionSearchParams,
  TopicRollDataParams, TopicRollDataResponse } from "./ApiType";

export class ApiService {

  //生成试卷
  static async GetTopicRollData(Params: TopicRollDataParams): Promise<TopicRollDataResponse> {


    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.GenerateExamPaper,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //生成单选题
  static async GetBankData(Params: getDataParams): Promise<QuestionDataResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.GetBankQuestion,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //生成判断题
  static async GetJudgeData(Params: getDataParams): Promise<QuestionDataResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.GetJudgeQuestion,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //生成多选题
  static async GetManyData(Params: getDataParams): Promise<QuestionDataResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.GetManyQuestion,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }


  //搜索
  static async Search(Params: QuestionSearchParams): Promise<QuestionDataResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.Search,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //添加收藏
  static async AddLike(Params: AddParams): Promise<AddResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.AddLike,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //错题收藏
  static async AddWrong(Params: AddParams): Promise<AddResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.AddWrong,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //收藏列表
  static async GetLikeList(Params: ListParams): Promise<ListResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.ListLike,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //错题列表
  static async GetWrongList(Params: ListParams): Promise<ListResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.ListWrong,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //搜藏搜索
  static async getSearchCollect(Params: ListParams): Promise<ListResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.SearchCollect,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }


  //搜索详情
  static async getSearchDetails(Params: DetailsParam): Promise<DetailsResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.SearchDetail,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //删除错题
  static async deleteWrong(Params: DetailsParam): Promise<AddResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.DeleteWrong,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

  //错题详情
  static async getWrongDetails(Params: DetailsParam): Promise<DetailsResponse> {
    const paramsString = Object.entries(Params)
      .map((entry: [string,object | string | number | boolean]) => {

        const key = entry[0]
        const value = entry[1]

        const valueStr = (value === null || value === undefined) ? '' : String(value)

        return `${encodeURIComponent(key)}=${encodeURIComponent(valueStr)}`
      })
      .join('&')

    return instance.post(ApiConfig.requestUrl.WrongDetail,paramsString,{
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    })
  }

}