tree grammar BuildCFG;

options
{
   tokenVocab=Mini;
   ASTLabelType=CommonTree;
}

/*
   Tree Parser -- typechecks given program
*/
@header
{
   import java.util.ArrayList;
}

@members
{
   ArrayList<Block> functionStarts = new ArrayList<Block>();
}

translate
   returns [ArrayList<Block> blocks = null;]
   :  ^(PROGRAM t=types d=declarations f=functions)
      {
         blocks = functionStarts;
      }
   ;

types
   :  ^(TYPES (t=type_decl)*)
   ;

type_decl
   :  ^(ast=STRUCT id=ID n=nested_decl)
   ;

nested_decl
   :  (f=field_decl)+
   ;

field_decl
   :  ^(DECL ^(TYPE t=type) id=ID)
   ;

type
   :  INT 
   |  BOOL 
   |  ^(STRUCT id=ID) 
   ;

declarations
   :  ^(DECLS (decl_list)*)
   ;

decl_list
   :  ^(DECLLIST ^(TYPE t=type) (id=ID)+)
   ;

functions
   :  ^(FUNCS (f=function {functionStarts.add($f.start);} )*)
   ;

function 
   returns [Block start = null;]
   scope { String name;
           int count;
           Block end;
           ArrayList<String> regValues;}
   @init { $function::count = 0; $function::regValues = new ArrayList<String>();}
   :  ^(ast=FUN id=ID { start = new Block($id.text + ":start");
                        $function::name = $id.text;
                        $function::end = new Block($id.text + ":end"); } p=parameters[start] r=return_type
         d=fun_decls s=statement_list[$p.end])
         {
            $s.end.connect($function::end);
         }
   ;

fun_decls
   :  ^(DECLS (fun_decl_list)*)
   ;

fun_decl_list
   :  ^(DECLLIST ^(TYPE t=type) (id=ID)+)
      {
         if (!$function::regValues.add($id.text))
         {
            // throw error
         }
      }
   ;

parameters[Block currentBlock]
   returns [Block end = null;]
   scope {Block blk;}
   @init{$parameters::blk = currentBlock;}
   :  ^(PARAMS (p=param_decl)*)
      {
         end = $parameters::blk;
      }
   ;

param_decl
   :  ^(DECL ^(TYPE t=type) id=ID)
      {
         $function::regValues.add($id.text);

         //loadinargument num, 0, r0
         int temp = $function::regValues.indexOf($id.text);
         $parameters::blk.ilocs.add(new Iloc("loadinargument", $id.text, ""+temp, "r"+temp));
      }
   ;

return_type
   :  ^(RETTYPE rtype) 
   ;

rtype
   :  t=type 
   |  VOID 
   ;

statement[Block currentBlock]
   returns [Block end = currentBlock;]
   scope { Block block; }
   @init { $statement::block = currentBlock; }
   :  (s=block[currentBlock]
      |  s=assignment
      |  s=print //
      |  s=invocation_stmt
      |  s=delete
      |  s=read
      |  s=return_stmt
      |  s=conditional
      |  s=loop
      )
   {
      end = $s.end;
   }
   ;

block[Block block]
   returns [Block end = null;]
   :  ^(BLOCK s=statement_list[block]) {$end = $s.end;}
   ;

statement_list[Block block]
   returns [Block end = block;]
   :  ^(STMTS (s=statement[end] {end = $s.end;})*)
   ;

assignment
   returns [Block end = null;]
   :  ^(ast=ASSIGN e=expression[$statement::block] l=lvalue)
      {
         end = $statement::block;
      }
   ;

print
   returns [Block end = null;]
   :  ^(ast=PRINT e=expression[$statement::block] (ENDL)?)
      {
         end = $statement::block;
         $end.ilocs.add(new Iloc("print", "r"));
      }
   ;

read
   returns [Block end = null;]
   :  ^(ast=READ l=lvalue)
      {
         end = $statement::block;
      }
   ;

conditional
   returns [Block end = null]
   @init { end = new Block($function::name + ":ifend:" + $function::count);
           Block thenBlock = new Block($function::name + ":then:" + $function::count);
           Block elseBlock = new Block($function::name + ":else:" + $function::count);
           $function::count++; }
   :  ^(ast=IF g=expression[$statement::block] t=block[thenBlock] {$statement::block.connect(thenBlock); thenBlock.connect(end);}
        (e=block[elseBlock] {$statement::block.connect(elseBlock); elseBlock.connect(end);} )?)
   ;

loop
   returns [Block end = null;]
   @init { end = new Block($function::name + ":whileend:" + $function::count);
           Block expBlock = new Block($function::name + ":whiletest:" + $function::count);
           $statement::block.connect(expBlock);
           Block bodyBlock = new Block($function::name + ":whilebody:" + $function::count);
           $function::count++;
           expBlock.connect(bodyBlock);
           expBlock.connect(end);
           bodyBlock.connect(expBlock); }
   :  ^(ast=WHILE e=expression[expBlock] b=block[bodyBlock] expression[bodyBlock])
   ;

delete
   returns [Block end = null;]
   :  ^(ast=DELETE e=expression[$statement::block])
      {
         end = $statement::block;
      }
   ;

return_stmt
   returns [Block end = null;]
   :  ^(ast=RETURN (e=expression[$statement::block])?)
      {
         $statement::block.connect($function::end);
         end = new Block($function::name + ":afterreturn:" + $function::count);
         $function::count++;
      }
   ;

invocation_stmt
   returns [Block end = null;]
   :  ^(ast=INVOKE id=ID ^(ARGS (e=expression[$statement::block] )*))
      {
         end = $statement::block;
      }
   ;

lvalue 
   :  id=ID
   |  ^(ast=DOT l=lvalue id=ID)
   ;

expression[Block currentBlock] 
   returns [int reg = -1; Block end = null]
   @init {end = currentBlock;}
   :  ^(ast=LT lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=GT lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=NE lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=LE lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=GE lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=PLUS lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=MINUS lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=TIMES lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=DIVIDE lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=EQ lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^((ast=AND | ast=OR) lft=expression[currentBlock] rht=expression[currentBlock])
   |  ^(ast=NOT e=expression[currentBlock])
   |  ^(ast=NEG e=expression[currentBlock])
   |  ^(ast=DOT e=expression[currentBlock] id=ID)
   |  ie=invocation_exp[currentBlock]
   |  id=ID
   |  i=INTEGER
   |  ast=TRUE
   |  ast=FALSE
   |  ^(ast=NEW id=ID)
   |  ast=NULL
   ;

invocation_exp[Block currentBlock]
   :  ^(ast=INVOKE id=ID ^(ARGS (e=expression[currentBlock] )*))
   ;
