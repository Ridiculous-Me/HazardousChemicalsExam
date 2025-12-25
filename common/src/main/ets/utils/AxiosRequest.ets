import axios, { AxiosError, AxiosResponse, InternalAxiosRequestConfig } from "@ohos/axios";
import { Toast } from "./Toast";

//创建Axios实例
export const instance = axios.create(
  {
    //请求基地址`
    baseURL: 'http://query.csweimei.cn/app/',
    //请求超市时间
    timeout: 6000,
  }
)

//请求拦截器
instance.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  return config
},(error: AxiosError) => {
  console.log('请求拦截err',error)
  return Promise.reject(error)
})

//响应拦截器
instance.interceptors.response.use((response: AxiosResponse) => {
  return response.data
}, (error: AxiosError) => {
  Toast.show('网络请求超时')
  console.log('响应拦截器err',error);
  return Promise.reject(error)
})
