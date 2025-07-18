package haxe.json5;

import haxe.json5.Token;

using StringTools;

class Parser {
	var tokens:Array<Token>;
	var currToken = 0;

	final numberRegex = new EReg("^(?:[+-]?(?:(?:[1-9]\\d*|0)(?:\\.\\d*)?|\\.\\d+)(?:[Ee][+-]?\\d+)?)$", "");
	final hexadecimalRegex = new EReg("^[+-]?(?:0x)[0-9a-f]+$", "i");

	@:allow(haxe.Json5)
	private function new(tokens:Array<Token>):Void {
		this.tokens = tokens;
	}

	public function parse():Any {
		final output = parseValue();
		if (currToken < tokens.length) invalidEof();
		return output;
	}

	private function parseValue():Any {
		final token = tokens[currToken];

		if (token == null) throw 'Premature document end';

		switch (token) {
			case TLBrace(_):
				return parseObject();

			case TLBracket(_):
				return parseArray();

			case TString(string, _):
				currToken++;
				return string;

			case TId(raw, pos):
				currToken++;
				return parseIdentifier(raw, pos);

			default:
				throw 'Cannot parse value "${TokenHelper.tokenToString(token)}" ${TokenHelper.extractPos(token)}';
		}
	}

	private function parseObject():Any {
		final firstToken = tokens[currToken++];
		var currentToken:Token = null;
		var nextIsComma = false;
		final output:Any = {};

		while (true) {
			currentToken = tokens[currToken];

			if (currentToken == null)
				throw 'Object must be closed with a right brace ${TokenHelper.extractPos(firstToken)}';

			switch (currentToken) {
				case TRBrace(_):
					// end of object
					currToken++;
					break;

				case TComma(_) if (nextIsComma):
					// trailing comma/separator comma
					currToken++;
					nextIsComma = false;

				case ((!nextIsComma && (_.match(TString(_)) || _.match(TId(_)))) => true):
					parseKeyValuePair(output);
					nextIsComma = true;

				default:
					throw 'Unexpected "${TokenHelper.tokenToString(currentToken)}" ${TokenHelper.extractPos(currentToken)}';
			}
		}

		return output;
	}

	private function parseArray():Array<Any> {
		final firstToken = tokens[currToken++];
		var currentToken:Token = null;
		var nextIsComma = false;
		final output:Array<Any> = [];

		while (true) {
			currentToken = tokens[currToken];

			if (currentToken == null)
				throw 'Array must be closed with a right bracket ${TokenHelper.extractPos(firstToken)}';

			switch (currentToken) {
				case TRBracket(_):
					// end of array
					currToken++;
					break;

				case TComma(_) if (nextIsComma):
					currToken++;
					nextIsComma = false;

				case (!nextIsComma => true):
					output.push(parseValue());
					nextIsComma = true;

				default:
					throw 'Unexpected "${TokenHelper.tokenToString(currentToken)}" ${TokenHelper.extractPos(currentToken)}';
			}
		}

		return output;
	}

	private function parseKeyValuePair(object:Any):Void {
		final keyToken = tokens[currToken];
		final key:String = switch (keyToken) {
			case TString(key, _), TId(key, _):
				key;
			default:
				throw 'This shouldn\'t be reachable.';
		};

		if (!nextTokenIsColon())
			throw 'Expected colon next to key "${key}" ${TokenHelper.extractPos(keyToken)}';

		if (Reflect.hasField(object, key))
			throw 'Duplicate key "${key}" ${TokenHelper.extractPos(keyToken)}';

		currToken++;

		final value = parseValue();
		Reflect.setProperty(object, key, value);
	}

	private function parseIdentifier(raw:String, pos:TokenPos):Any {
		switch (raw) {
			case 'null':
				return null;

			case 'true':
				return true;

			case 'false':
				return false;

			case 'Infinity', '+Infinity':
				return Math.POSITIVE_INFINITY;

			case '-Infinity':
				return Math.NEGATIVE_INFINITY;

			case 'NaN', '+NaN', '-NaN':
				return Math.NaN;

			case (hexadecimalRegex.match(_) => true):
				return Std.parseInt(raw);

			case (numberRegex.match(_) => true):
				return Std.parseFloat(raw);

			default:
				throw 'Couldn\'t parse value "${raw}" ${pos}';
		}
	}

	private function nextTokenIsColon():Bool {
		final token = tokens[++currToken];
		return token != null && token.match(TColon(_));
	}

	private function invalidEof():Void {
		final token = tokens[currToken];
		final pos = TokenHelper.extractPos(token);

		var char = TokenHelper.tokenToString(token);
		if (char.length > 1) char = char.charAt(0);

		throw 'Invalid non-whitespace character after value: "${char}" ' + pos;
	}
}
