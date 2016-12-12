package Treex::Tool::Segment::LA::RuleBased;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Segment::RuleBased';


my $UNBREAKERS = qr{
    \p{Upper}            # single uppercase letters
    |AA|AAA|AEO|AEM|AIM|AER|MILL|AN|ANN|ANT|TER|ABB|AED|AEDILIC|AEL|AEPP|ARG|AR   # classical abbreviations
    |AV|AVG|AVGG|AVGGG|AVR|AVT|PR|BB|DD|BN|RP|BRT|BX|BMT|CC|CES|CL|CN|COH|COL|COLL
    COM|CON|COR|COS|COSS|CS|CVR|CAL|VV|CESS|COI|CS|DES|DD|DEC|DES|DNO|DEP|NN|EG|EQ
    |EL|EPI|EPO|EXT|ET|EXV|EP|TM|EX|VIV|DISC|FR|FL|FF|FS|GL|GN|HBQ|HER|HERC|HH|IA
    |ID|IM|IMP|ILL|IVL|IVN|IDNE|INB|IND|KAL|KL|LB|LEG|LIB|LL|LVD|LV|LB|MES|MESS|MNT
    |MON|MVN|MM|MRT|NEP|NN|NNO|NNR|NOB|NOBR|NOV|OB|OR|XTO|OMS|OP|PR|CONS|PRB|PZ|PP
    |QQ|RP|RESP|RET|RR|SAC|SER|SN|SER|SN|EE|SS|SC|SD|SSA|TB|TI|TIB|TR|TRB|TM|TVL
    |TT|VA|VB|VV|XPC|XC|XS|XCS
    |Ab|Abp|Abs|Absloluo|Aplica|Appatis|Archiepus|Aucte|Adm|Rev|Adv|Alb|al|An|Ann   # general, ecclesiastical, titles abbreviations
    |Ant|Apost|Ap|Sed|Leg|Archiep|Archid|Archiprd|Authen|Aux|Ben|Benevol|Bon|Mem
    |Bro|Se|Cam|Can|Canc|Cap|Seq|Capel|Caus|Cen|Eccl|Cla|Cl|Clico|Clun|Cod|Cog
    |Spir|Coll|Cone|Comm|Prec|Compl|Con|Conf|Doct|Pont|Cons|Consecr|Const|Cr
    |Canice|Card|Cens|Circumpeone|Coione|Confeone|Consciae|Dni|Dr|iur|Discreoni
    |Dispensao|Dec|Def|Dom|Doxol|Dupl|Maj|El|Episc|Et|Evang|Ex|Exe|Ecclae|Ecclis
    |Effum|Epus|Excoe|Exit|Fr|Frum|Fel|Mem|Rec|Fer|Fund|Gen|Gl|Gr|Grad|Grat|Humil
    |Humoi|hebd|Hom|hor|Id|Igr|Ind|Inq|Is|Infraptum|Intropta|Irregulte|Jo|Joann|Jud
    |Jur|Kal|Lia|Litma|Lre|Lte|Laic|Laud|loc|cit|Lect|Legit|Lib|Lo|Lic|Litt|Loc|Lov
    |Lovan|Lud|Mag|Mand|Mart|Mat|Matr|Mgr|Miss|Apost|Magro|Mir|Miraone|Mrimonium
    |Nultus|Nativ|Nigr|No|Nob|Noct|Non|Nostr|Not|Ntri|Nup|Ob|Oct|Omn|Op|Cit|Or|Ord
    |Orat|Oxon|Ordinaoni|Ordio|Pbr|Penia|Peniaria|Pntium|Pontus|Pr|Pror|Ptur|Ptus
    |Pa|Pact|Pasch|Patr|Pent|Ph|Phil|Poenit|Pont|Max|Poss|Praef|Presbit|Prof|Prop
    |Fid|Propr|Prov|Ps|Pub|Publ|Purg|Can|Quadrag|Quinquag|Qd|Qmlbt|Qtnus|Reg|Relione
    |Rlari|Roma|Rescr|Req|Resp|Rit|Rom|Rt|Rev|Rub|Rubr|sc|scil|Sacr|Sab|Sabb|Saec
    |Sal|Salmant|Semid|Sexag|Sig|Simpl|Com|Soc|Off|Petr|Sr|Suffr|Syn|Salri|Snia
    |Sntae|Stae|Spealer|Supplioni|Theolia|Tli|Tm|Tn|Temp|Test|Theol|Tit|Ult|Usq
    |Ux|gr|Ven|Vrae|Vest|Vac|Val|Vat|Vba|Vers|Vesp|Vic|For|Vid|Videl|Vig|Viol
    |Virg|Virid|Camald|Cart|Cest|Merced|Cap|Fratr|Praed|Ord|Praem|Trinit
}x;    

override unbreakers => sub {
    return $UNBREAKERS;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Segment::LA::RuleBased - rule based sentence segmenter for Latin

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a English specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

See L<Treex::Block::W2A::Segment>

=head1 AUTHOR

Christophe Onambélé <christophe.onambele@unicatt.it>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan - Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

