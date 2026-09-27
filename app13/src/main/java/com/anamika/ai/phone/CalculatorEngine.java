package com.anamika.ai.phone;

/** Small deterministic arithmetic parser: + - * / % ^ and parentheses. */
public final class CalculatorEngine {
    private CalculatorEngine(){}

    public static double evaluate(String expression) {
        if(expression==null) throw new IllegalArgumentException("Empty expression");
        return new Parser(expression).parse();
    }

    private static final class Parser {
        private final String s;
        private int p;
        Parser(String s){this.s=s.replace("×","*").replace("÷","/");}

        double parse(){
            double v=expression();
            spaces();
            if(p!=s.length()) throw new IllegalArgumentException("Unexpected: "+s.charAt(p));
            return v;
        }
        double expression(){
            double v=term();
            while(true){
                spaces();
                if(eat('+'))v+=term();
                else if(eat('-'))v-=term();
                else return v;
            }
        }
        double term(){
            double v=power();
            while(true){
                spaces();
                if(eat('*'))v*=power();
                else if(eat('/')){double d=power(); if(d==0)throw new ArithmeticException("Division by zero"); v/=d;}
                else if(eat('%')){double d=power(); if(d==0)throw new ArithmeticException("Modulo by zero"); v%=d;}
                else return v;
            }
        }
        double power(){
            double v=factor();
            spaces();
            if(eat('^')) v=Math.pow(v,power());
            return v;
        }
        double factor(){
            spaces();
            if(eat('+')) return factor();
            if(eat('-')) return -factor();
            if(eat('(')){double v=expression(); if(!eat(')'))throw new IllegalArgumentException("Missing )"); return v;}
            int start=p;
            while(p<s.length()&&(Character.isDigit(s.charAt(p))||s.charAt(p)=='.'))p++;
            if(start==p)throw new IllegalArgumentException("Number expected");
            return Double.parseDouble(s.substring(start,p));
        }
        boolean eat(char c){spaces(); if(p<s.length()&&s.charAt(p)==c){p++;return true;} return false;}
        void spaces(){while(p<s.length()&&Character.isWhitespace(s.charAt(p)))p++;}
    }
}
