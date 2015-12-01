<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs" version="2.0">

    <!-- 
        * This code, without EXTENSIVE commenting is roughly 230 lines SHORT.
        
        Coursework submission for XML and Structured Documents at Queen Mary U. of London.
        
        This is an XSL parser implementing the bottom up CYK (Cocke-Kasami-Younger) algorithm
        used to parse CFG or in our case to parse an English sentence, given by a set of 
        grammar rules and lexical rules for said sentence(s). 
        
        The parser works only on sentences whose structure is defined by the corupus.xsd schema.
        And whose lexical rules are defined in a separate file together with relating grammar
        ruleset.
        
        @Authors: Ben Steer & Alhamza Alnaimi
        @Group ID: 1
    -->

    <xsl:template match="/">

        <!-- 
            Note that we put everything into a TreeBank which contains
            many trees (sentences). This is to improve readability.
            
            The xsi:noname[...]Location specifies the schema which
            produced XML document must adhere to.
        -->
        <TreeBank xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:noNamespaceSchemaLocation="tree.xsd">

            <!-- Load required lexical rules and grammar rules as a doc -->
            <xsl:variable name="doc" select="doc('englishGrammar.xml')"/>

            <!-- For each s tag in our curr. doc, call the template //s -->
            <xsl:variable name="pre-processed">
                <xsl:apply-templates select="//s">
                    <xsl:with-param name="grammar" select="$doc/grammar"/>
                </xsl:apply-templates>
            </xsl:variable>

            <!-- 
                We then pass the pre-processed data to our build tree function.
                Which, as it name suggests, builds a grammar tree from given data.
                Ps. if you wish to see how the pre-processed data looks, then
                comment or deactive below template call. And remove variable
                declarations around above template for //s!
            -->
            <xsl:call-template name="buildTrees">
                <xsl:with-param name="data" select="$pre-processed"/>
            </xsl:call-template>

        </TreeBank>

    </xsl:template>

    <!-- the //s template accepts the doc as parameter -->
    <xsl:template match="//s">
        <xsl:param name="grammar"/>

        <!-- We assign each child element of the doc to a variable -->
        <xsl:variable name="lexical" select="$grammar/lexicalRules"/>
        <xsl:variable name="rules" select="$grammar/rules"/>

        <!-- 
            For each word in our currently parsed sentence,
            we tokenize (split) by white space, forming words
            individually. These are output under a respective
            <word> XML tag, and saved under the var. 'words'.
         -->
        <xsl:variable name="words">
            <xsl:for-each select="tokenize(current(),' ')">
                <word>
                    <xsl:value-of select="."/>
                </word>
            </xsl:for-each>
        </xsl:variable>

        <!-- 
            Lexicalise each word in the sentence, this represents us applying unit production Rj for ai. Then 
            save said lexicalised words into a row type of structure, representing our first row in the CYK
        -->
        <xsl:variable name="lexicalised">
            <row id="1">
                <!-- For each word, we find it's lexical category(ies) -->
                <xsl:for-each select="$words/word">
                    <xsl:variable name="w" select="current()"/>

                    <!-- We then output a cell tag -->
                    <cell row="1" id="{position()}">

                        <!-- 
                            Of which for each possible lexical rule that applies to 
                            our current word, we output under a cat element tag.
                        -->
                        <xsl:for-each select="$lexical/word[. = $w]/@cat">
                            <cat>
                                <value>
                                    <xsl:value-of select="current()"/>
                                </value>
                                <child>
                                    <xsl:value-of select="$w"/>
                                </child>
                            </cat>
                        </xsl:for-each>
                    </cell>
                </xsl:for-each>
            </row>
        </xsl:variable>

        <!-- 
            We then take said above data structure, and pass it to our recursive 
            method, together with the rules and the starting row which we want to 
            apply the CYK algorithm to.
        -->
        <sentence value="{.}">
            <xsl:call-template name="CYK">
                <!-- All of our words -->
                <xsl:with-param name="words" select="$words"/>

                <!-- The lexicalised data structure so far -->
                <xsl:with-param name="lexicalised" select="$lexicalised"/>

                <!-- The rules which the CFG adheres to -->
                <xsl:with-param name="rules" select="$rules"/>

                <!-- 
                    The starting row i = 2, as remember first 
                    row holds the lexical values for our words 
                 -->
                <xsl:with-param name="i" select="2"/>
            </xsl:call-template>
        </sentence>
    </xsl:template>

    <xsl:template name="CYK">
        <xsl:param name="words"/>
        <xsl:param name="lexicalised"/>
        <xsl:param name="rules"/>
        <xsl:param name="i"/>

        <xsl:variable name="size" select="count($words/word)"/>

        <!--
            For each curr row starting from i and to the upper triangle of our sentence,
            we process the rule(s)/word and possible parent of said rule(s)/word.        
        -->
        <xsl:variable name="lexRows" select="$lexicalised/row"/>

        <!--  if / else -->
        <xsl:choose>

            <!-- 
                IF the current row is less or equal to the size 
                of words in curr sentence can be seens as triangular 
                combinations that could form a  possible sentence 
                consisting of lexcial pairs.
            -->
            <xsl:when test="$i &lt;= $size">
                <xsl:variable name="nextRow">
                    <row id="{$i}">

                        <!-- Then for that row we want to iterate over each cell and assigned lex -->
                        <xsl:for-each select="1 to count($words/word) - $i + 1">
                            <xsl:variable name="j" select="current()"/>

                            <cell row="{$i}" id="{$j}">
                                <!-- And for each cell you iterate over the partition span (triangle) -->
                                <xsl:for-each select="1 to $i - 1">
                                    <xsl:variable name="k" select="current()"/>

                                    <!-- parent value returned by the grammarChecker is saved -->
                                    <xsl:variable name="parent">
                                        <xsl:call-template name="grammarChecker">
                                            <xsl:with-param name="rules" select="$rules"/>

                                            <!-- as first arg pass the current cell j in current row i. -->
                                            <xsl:with-param name="first"
                                                select="$lexRows[$k]/cell[$j]"/>

                                            <!-- 
                                                and sec arg as row i - k, and cell j + k, forming a 
                                                triangular increase, adhering to the CYK algorithm 
                                            -->
                                            <xsl:with-param name="second"
                                                select="$lexRows[$i - $k]/cell[$j + $k]"/>
                                        </xsl:call-template>
                                    </xsl:variable>

                                    <!-- We then output the value of the parent -->
                                    <xsl:copy-of select="$parent"/>
                                </xsl:for-each>

                            </cell>
                        </xsl:for-each>
                    </row>
                </xsl:variable>

                <!-- 
                    and recursively call the function with the newly formed row now 
                    added to our previous data structure, containing previous rows. 
                -->
                <xsl:call-template name="CYK">
                    <xsl:with-param name="words" select="$words"/>

                    <xsl:with-param name="lexicalised">
                        <!-- of course we must maintain previous rows -->
                        <xsl:copy-of select="$lexRows"/>

                        <!-- and add the newly formed one -->
                        <xsl:copy-of select="$nextRow"/>
                    </xsl:with-param>

                    <!-- 
                        passing same rules as prev. However i now 
                        starting at +1 representing the row changes
                    -->
                    <xsl:with-param name="rules" select="$rules"/>
                    <xsl:with-param name="i" select="$i+1"/>
                </xsl:call-template>

            </xsl:when>

            <!-- 
                And if we already iterated through all triangular 
                rows, THEN simply return lexicalised data structure.
            -->
            <xsl:otherwise>
                <xsl:copy-of select="$lexicalised"/>
            </xsl:otherwise>

        </xsl:choose>
    </xsl:template>

    <!-- 
        A template functionm which takes two paramaters representing NLP rules, 
        and searches for a parent according to grammar rules defined by first arg 
    -->
    <xsl:template name="grammarChecker">
        <xsl:param name="rules"/>
        <xsl:param name="first"/>
        <xsl:param name="second"/>

        <!-- for each rule in provided grammar -->
        <xsl:for-each select="$rules/mother">
            <xsl:variable name="mother" select="."/>

            <!-- and for each possible lexicals for the first argument -->
            <xsl:for-each select="$first/cat/value">
                <xsl:variable name="postFst" select="position()"/>
                <xsl:variable name="firstCat" select="."/>

                <!-- and possible lexicals for the second argument -->
                <xsl:for-each select="$second/cat/value">
                    <xsl:variable name="posSnd" select="position()"/>

                    <!-- we check if there exists a parent that has both as a child -->
                    <xsl:if
                        test="($mother/daughter[1]/@cat = $firstCat) and ($mother/daughter[2]/@cat = .)">

                        <!-- 
                            we then output said parent's value inside cat, 
                            with the id of the children that formed it 
                        -->
                        <cat>
                            <value>
                                <xsl:value-of select="$mother/@cat"/>
                            </value>

                            <!-- 
                                here you can see that we output the id of the row, the cell
                                and also the cat position for which we found the adhering rule
                             -->
                            <child row="{$first/@row}" cell="{$first/@id}" cat="{$postFst}"/>
                            <child row="{$second/@row}" cell="{$second/@id}" cat="{$posSnd}"/>
                        </cat>
                    </xsl:if>
                </xsl:for-each>

            </xsl:for-each>

        </xsl:for-each>
    </xsl:template>

<!-- 
     Below is where we iterate through our preprocessed data
     to build a tree adhering to the FINAL structure requested. 
-->

    <!-- 
        Takes as parameter a set of pre-processed data w.
        custom structure containing the sentence, indv. 
        words, and their rules, and preceeding rules which
        forms the CFG adhering to the ruleset provided.
        
        This method then parses the data structure ottom up
        and returns a tree with the root node s, and the 
        children the values which forms the s.
    -->
    <xsl:template name="buildTrees">
        <xsl:param name="data"/>

        <xsl:for-each select="$data/sentence">
            <tree>
               
                <xsl:variable name="s" select="."/>

                <!-- Recursively build a tree, starting at s -->
                
                <!-- ME -->
                <!-- <xsl:for-each select="$s/row[last()]/cell/cat"> -->
                    <xsl:call-template name="reIter">
                        <xsl:with-param name="sentence" select="$s"/>
                        
                        <!-- 
                            Ignore other possibilties of sentences only select first 
                            
                            Please note, that if you wish for the tree-bank to include
                            all possible ways that a sentence could be formed, then
                            simply uncomment the for each loop labeled 'Me', and
                            change the value of  the variable 'root' below to simply
                            select="."
                        -->
                        <xsl:with-param name="root" select="$s/row[last()]/cell/cat[1]"/>
                    </xsl:call-template>
                <!-- </xsl:for-each> -->
                
            </tree>
        </xsl:for-each>
    </xsl:template>

    <!-- 
        Takes as parameter a root node, and recursively
        iterates through all of its  children, until
        the last cell has no more children nodes, or in 
        our case the child has a value (i.e. we hit a word)
    -->
    <xsl:template name="reIter">
        <!-- note that the root is the current cell -->
        <xsl:param name="sentence"/>
        <xsl:param name="root"/>

        <xsl:choose>
            <!-- If the current cat (root) has a child with text -->
            <xsl:when test="not($root/child = '')">

                <!-- 
                    then output the value of the cild inside a <word> element
                    with attribute equal to the lexical cat it belongs to 
                -->
                <word cat="{$root/value}">
                    <xsl:value-of select="$root/child"/>
                </word>
            </xsl:when>

            <!-- Else split the tree into two, and recurisvely do same for each half -->
            <xsl:otherwise>

                <!-- Output a element <node> with attribute of it's cat -->
                <node cat="{$root/value}">

                    <!-- and for the first child that formed above call recurisively -->
                    <xsl:variable name="fst" select="$root/child[1]"/>

                    <xsl:call-template name="reIter">
                        <xsl:with-param name="sentence" select="$sentence"/>

                        <!-- 
                            Where we pass the overall sentence at row given by the 
                            @row attribute of our first child, and the cell position
                            given by the @cell attribute. Finally we also chose to 
                            pass the cat element which originally formed the data. 
                            This helps with the likes of word 'tuna' that both can be
                            formed by 'cn' and 'np. If confused, please refer to printing
                            the pre-processed data in the '/' template.
                            
                            This also allows us to print all possible trees that could form
                            a sentence, for the cases of the last sentence given, which can 
                            have 4 different possible trees. All we need to do is apply a
                            for each loop to print all of them instead of always passing cat[1]
                            in the buildTrees above.
                        -->
                        <xsl:with-param name="root"
                            select="$sentence/row[number($fst/@row)]/cell[number($fst/@cell)]/cat[number($fst/@cat)]"
                        />
                    </xsl:call-template>

                    <!-- and for second child, do same as above. -->
                    <xsl:variable name="snd" select="$root/child[2]"/>

                    <xsl:call-template name="reIter">
                        <xsl:with-param name="sentence" select="$sentence"/>

                        <xsl:with-param name="root"
                            select="$sentence/row[number($snd/@row)]/cell[number($snd/@cell)]/cat[number($snd/@cat)]"
                        />
                    </xsl:call-template>
                </node>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>