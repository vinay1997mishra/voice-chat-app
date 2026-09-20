package com.anamika.ai.phone;

/** Small offline arithmetic parser: + - * / % ^ and parentheses. */
public final class CalculatorEngine {
    private CalculatorEngine(){}

    public static String calculate(String raw){
        if(raw==null) throw new IllegalArgumentException("Empty calculation.");
        String expr=raw.toLowerCase(java.util.Locale.ROOT)
                .replace("×","*").replace("x","*").replace("÷","/")
                .replaceAll("(?i)(calculate|calc|hisaab|hisab|kitna hoga|kya hoga|कैलकुलेट|हिसाब|गणना)","")
                .replaceAll("(?i)percent of","%*")
                .replaceAll("[^0-9+\\-*/%^(). ]","");
        if(expr.trim().isEmpty()) throw new IllegalArgumentException("Calculation expression nahi mila.");
        Parser p=new Parser(expr);
        double v=p.parse();
        if(Double.isNaN(v)||Double.isInfinite(v)) throw new IllegalArgumentException("Invalid calculation.");
        long rounded=Math.round(v);
        if(Math.abs(v-rounded)<1e-10) return String.valueOf(rounded);
        java.math.BigDecimal bd=java.math.BigDecimal.valueOf(v).stripTrailingZeros();
        return bd.toPlainString();
    }

    private static final class Parser{
        private final String s; private int i=0;
        Parser(String s){this.s=s;}
        double parse(){
            double v=expr(); skip();
            if(i!=s.length()) throw new IllegalArgumentException("Unexpected: "+s.charAt(i));
            return v;
        }
        double expr(){
            double v=term();
            while(true){ skip(); if(match('+')) v+=term(); else if(match('-')) v-=term(); else return v; }
        }
        double term(){
            double v=power();
            while(true){
                skip();
                if(match('*')) v*=power();
                else if(match('/')) { double d=power(); if(d==0) throw new IllegalArgumentException("Division by zero."); v/=d; }
                else if(match('%')) v=v/100.0;
                else return v;
            }
        }
        double power(){
            double v=unary(); skip(); if(match('^')) v=Math.pow(v,power()); return v;
        }
        double unary(){
            skip(); if(match('+')) return unary(); if(match('-')) return -unary();
            if(match('(')){ double v=expr(); skip(); if(!match(')')) throw new IllegalArgumentException("Missing )"); return v; }
            return number();
        }
        double number(){
            skip(); int st=i; boolean dot=false;
            while(i<s.length()){
                char c=s.charAt(i);
                if(Character.isDigit(c)) i++;
                else if(c=='.'&&!dot){dot=true;i++;}
                else break;
            }
            if(st==i) throw new IllegalArgumentException("Number expected.");
            return Double.parseDouble(s.substring(st,i));
        }
        void skip(){while(i<s.length()&&Character.isWhitespace(s.charAt(i)))i++;}
        boolean match(char c){if(i<s.length()&&s.charAt(i)==c){i++;return true;}return false;}
    }
}
