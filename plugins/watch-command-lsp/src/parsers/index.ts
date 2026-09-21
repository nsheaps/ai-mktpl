import { OutputParser, ParserType, RegexPatternConfig } from "../types.js";
import { GenericParser } from "./generic.js";
import { JestParser } from "./jest.js";
import { EslintParser } from "./eslint.js";
import { TscParser } from "./tsc.js";
import { RegexParser } from "./regex.js";

export function createParser(type: ParserType, regexPatterns?: RegexPatternConfig[]): OutputParser {
  switch (type) {
    case "generic":
      return new GenericParser();
    case "jest":
      return new JestParser();
    case "eslint":
      return new EslintParser();
    case "tsc":
      return new TscParser();
    case "regex":
      if (!regexPatterns?.length) {
        throw new Error("regex parser requires at least one pattern in regexPatterns");
      }
      return new RegexParser(regexPatterns);
    default:
      return new GenericParser();
  }
}

export { GenericParser, JestParser, EslintParser, TscParser, RegexParser };
