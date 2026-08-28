import axios from "axios";

export type ZutoolTimeEntry = {
  time: string;
  pressure: number;
  pressure_level: number;
};

export type ZutoolTodayResponse = {
  place_name: string;
  today: ZutoolTimeEntry[];
};

export async function fetchTodayWeather(placeId: string): Promise<ZutoolTodayResponse> {
  const url = `https://zutool.jp/api/getweatherstatus/${placeId}`;
  const response = await axios.get(url, { timeout: 5000 });

  const data = response.data as ZutoolTodayResponse;

  if (!data.place_name || !Array.isArray(data.today)) {
    throw new Error("Unexpected response from zutool API");
  }

  return data;
}
