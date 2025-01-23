package Treex::Tool::Lexicon::EN::PersonalRoles;
use utf8;
use strict;
use warnings;

my %IS_PERSONAL_ROLE;
while (<DATA>) {
    for (split) {
        $IS_PERSONAL_ROLE{$_} = 1;
    }
}
close DATA;

sub is_personal_role {
    return $IS_PERSONAL_ROLE{ $_[0] }
}

1;

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::EN::PersonalRoles

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::EN::PersonalRoles;
 print Treex::Tool::Lexicon::EN::PersonalRoles::is_personal_role('actor');
 # prints 1

=head1 DESCRIPTION

A list of personal roles which such as I<author, cardinal, citizen,...>.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

__DATA__

abbot accountant actor administrator admirer adviser advisor advocate agent aide alderman amateur
ambassador analyst apprentice archbishop architect artist assistant associate astronomer attorney
auditor author baker bandit banker baron barrister bass bassist benefactor biologist bishop blacksmith
boss boxer boyfriend brigadier broadcaster broker brother brother-in-law builder bursar businessman
butcher cabinetmaker cameraman campaigner candidate captain cardinal cardiologist celebrity cellist
ceo chair chairman chairperson challenger champion chancellor chap chef chemist chief child citizen
clerk climber coach co-author co-founder collaborator colleague collector colonel columnist comedian
comic commandant commander commentator commissionaire commissioner companion composer comrade conductor
congressman conservationist constable consultant contender contractor controller convict cook coordinator
co-ordinator cop correspondent council councillor counsel counsellor cousin criminal critic curator
custodian cyclist dad dancer daughter dealer defender delegate deputy designer detective diplomat director
director-general disciple doctor driver drummer duke economist editor educationalist electrician emissary
emperor employee engineer entrepreneur envoy executive exile expert farmer father father-in-law fighter
finalist fisherman footballer foreman founder friend gardener general geologist girl goalie goalkeeper
governor graduate grandfather grandmaster grandson guard guardsman guest guide guitarist gunner gynaecologist
head headmaster headmistress historian husband illustrator inspector instructor inventor investor joiner
journalist judge justice keeper keyboardist kid king kinsman knight lady landlord landowner laureate lawyer
leader lecturer librarian lieutenant liquidator listener locksmith lodger lord lover magician magistrate maid
major maker man manager manufacturer marksman marshal marshall martyr master mathematician mayor mechanic
medic member merchant millionaire minister miss mister mistress mother musician nanny naturalist navigator
negotiator neighbour nephew niece novelist nurse officer official operator opponent organiser owner painter
pal partner passenger pastor pensioner photographer physician physicist pianist pilot pioneer player playwright
poet police policeman politician pope porter practitioner preacher president priest prince princess principal
prisoner producer professor proprietor prosecutor psychiatrist psychologist publican publicist publisher queen
radical raider rector referee reporter representative republican researcher retailer retiree rider rival runner
sailor salesman scholar schoolmate scientist scout screenwriter sculptor seaman secretary senator sergeant
servant shepherd sheriff singer sister skipper smith sociologist soldier solicitor soloist son speaker specialist
spokesman spokesperson spokeswoman squire staff star stockbroker stonemason student stylist successor
superintendent superstar supervisor supplier supporter surgeon surveyor teacher teammate technician tenant
theologian theorist thief trainee trainer traveller treasurer trooper trumpeter trustee tsar tutor umpire uncle
understudy unionist veteran vice-chairman vice-president victim victor violinist vocalist waiter warden widow
wife winner witness worker writer youngster zoologist
