# --
# Kernel/Modules/AgentITSMChangeConditionEdit.pm - the OTRS::ITSM::ChangeManagement condition edit module
# Copyright (C) 2003-2010 OTRS AG, http://otrs.com/
# --
# $Id: AgentITSMChangeConditionEdit.pm,v 1.2 2010-01-19 23:56:22 ub Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMChangeConditionEdit;

use strict;
use warnings;

use Kernel::System::ITSMChange;
use Kernel::System::ITSMChange::ITSMCondition;
use Kernel::System::Valid;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.2 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (qw(ConfigObject ParamObject DBObject LayoutObject LogObject)) {
        if ( !$Self->{$Object} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $Object!" );
        }
    }

    # create needed objects
    $Self->{ChangeObject}    = Kernel::System::ITSMChange->new(%Param);
    $Self->{ConditionObject} = Kernel::System::ITSMChange::ITSMCondition->new(%Param);
    $Self->{ValidObject}     = Kernel::System::Valid->new(%Param);

    # get config of frontend module
    $Self->{Config} = $Self->{ConfigObject}->Get("ITSMChange::Frontend::$Self->{Action}");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # store needed parameters in %GetParam
    my %GetParam;
    for my $ParamName (
        qw(ChangeID ConditionID Name Comment ExpressionConjunction ValidID Save AddAction AddExpression)
        )
    {
        $GetParam{$ParamName} = $Self->{ParamObject}->GetParam( Param => $ParamName );
    }

    # check needed stuff
    for my $Needed (qw(ChangeID ConditionID)) {
        if ( !$GetParam{$Needed} ) {
            $Self->{LayoutObject}->ErrorScreen(
                Message => 'No $Needed is given!',
                Comment => 'Please contact the admin.',
            );
            return;
        }
    }

    # check permissions
    my $Access = $Self->{ChangeObject}->Permission(
        Type     => $Self->{Config}->{Permission},
        ChangeID => $GetParam{ChangeID},
        UserID   => $Self->{UserID},
    );

    # error screen
    if ( !$Access ) {
        return $Self->{LayoutObject}->NoPermission(
            Message    => "You need $Self->{Config}->{Permission} permissions!",
            WithHeader => 'yes',
        );
    }

    # get change data
    my $ChangeData = $Self->{ChangeObject}->ChangeGet(
        ChangeID => $GetParam{ChangeID},
        UserID   => $Self->{UserID},
    );

    # check if change is found
    if ( !$ChangeData ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Change $GetParam{ChangeID} not found in database!",
            Comment => 'Please contact the admin.',
        );
    }

    # get valid list
    my %ValidList = $Self->{ValidObject}->ValidList();

    # ------------------------------------------------------------ #
    # condition save (also add expression / add action)
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Save' ) {

        # if this is a new condition
        if ( $GetParam{ConditionID} eq 'NEW' ) {

            # create a new condition
            $GetParam{ConditionID} = $Self->{ConditionObject}->ConditionAdd(
                ChangeID              => $GetParam{ChangeID},
                Name                  => $GetParam{Name},
                ExpressionConjunction => $GetParam{ExpressionConjunction},
                Comment               => $GetParam{Comment},
                ValidID               => $GetParam{ValidID},
                UserID                => $Self->{UserID},
            );

            # check error
            if ( !$GetParam{ConditionID} ) {
                $Self->{LayoutObject}->ErrorScreen(
                    Message => 'Could not create new condition!',
                    Comment => 'Please contact the admin.',
                );
                return;
            }
        }

        # update an existing condition
        else {

            # update the condition
            my $Success = $Self->{ConditionObject}->ConditionUpdate(
                ConditionID           => $GetParam{ConditionID},
                Name                  => $GetParam{Name},
                ExpressionConjunction => $GetParam{ExpressionConjunction},
                Comment               => $GetParam{Comment},
                ValidID               => $GetParam{ValidID},
                UserID                => $Self->{UserID},
            );

            # check error
            if ( !$Success ) {
                $Self->{LayoutObject}->ErrorScreen(
                    Message => "Could not update ConditionID $GetParam{ConditionID}!",
                    Comment => 'Please contact the admin.',
                );
                return;
            }
        }

        # if just the save button was pressed, redirect to condition overview
        if ( $GetParam{Save} ) {
            return $Self->{LayoutObject}->Redirect(
                OP => "Action=AgentITSMChangeCondition;ChangeID=$GetParam{ChangeID}",
            );
        }

        # if expression add button was pressed
        elsif ( $GetParam{AddExpression} ) {

        }

        # if action add button was pressed
        elsif ( $GetParam{AddAction} ) {

        }

        # show the edit view again
        return $Self->{LayoutObject}->Redirect(
            OP =>
                "Action=AgentITSMChangeConditionEdit;ChangeID=$GetParam{ChangeID};ConditionID=$GetParam{ConditionID}",
        );
    }

    # ------------------------------------------------------------ #
    # condition edit view
    # ------------------------------------------------------------ #
    if ( !$Self->{Subaction} ) {

        my %ConditionData;

        # get ConditionID
        $ConditionData{ConditionID} = $GetParam{ConditionID};

        # if this is an existing condition
        if ( $ConditionData{ConditionID} ne 'NEW' ) {

            # get condition data
            my $Condition = $Self->{ConditionObject}->ConditionGet(
                ConditionID => $ConditionData{ConditionID},
                UserID      => $Self->{UserID},
            );

            # check if the condition belongs to the given change
            if ( $Condition->{ChangeID} ne $GetParam{ChangeID} ) {
                return $Self->{LayoutObject}->ErrorScreen(
                    Message => "ConditionID $ConditionData{ConditionID} belongs to "
                        . " ChangeID $Condition->{ChangeID} and not to the given $GetParam{ChangeID}!",
                    Comment => 'Please contact the admin.',
                );
            }

            # add data from condition
            %ConditionData = ( %ConditionData, %{$Condition} );

            # show existing expressions
            $Self->_ExpressionOverview(
                %ConditionData,
            );

            # TODO
            #            # show existing actions
            #            $Self->_ActionOverview(
            #                %ConditionData,
            #            );

        }

        # output header
        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        # generate ValidOptionString
        $ConditionData{ValidOptionString} = $Self->{LayoutObject}->BuildSelection(
            Data       => \%ValidList,
            Name       => 'ValidID',
            SelectedID => $ConditionData{ValidID} || ( $Self->{ValidObject}->ValidIDsGet() )[0],
            Sort       => 'NumericKey',
        );

        # generate output
        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AgentITSMChangeConditionEdit',
            Data         => {
                %Param,
                %{$ChangeData},
                %ConditionData,
            },
        );
        $Output .= $Self->{LayoutObject}->Footer();

        return $Output;
    }
}

# show existing expressions
sub _ExpressionOverview {
    my ( $Self, %Param ) = @_;

    # get existing expressions
    my $ExpressionIDsRef = $Self->{ConditionObject}->ExpressionList(
        ConditionID => $Param{ConditionID},
        UserID      => $Self->{UserID},
    );

    return if !$ExpressionIDsRef;
    return if ref $ExpressionIDsRef ne 'ARRAY';
    return if !@{$ExpressionIDsRef};

    my %Data;

    EXPRESSIONID:
    for my $ExpressionID ( sort { $a cmp $b } @{$ExpressionIDsRef} ) {

        # get condition data
        my $ExpressionData = $Self->{ConditionObject}->ExpressionGet(
            ExpressionID => $ExpressionID,
            UserID       => $Self->{UserID},
        );

        next EXPRESSIONID if !$ExpressionData;

        # output overview row
        $Self->{LayoutObject}->Block(
            Name => 'ExpressionOverviewRow',
            Data => {},
        );

        # show object selection
        $Self->_ObjectSelection(
            %{$ExpressionData},
        );

        # show selecor selection
        $Self->_SelectorSelection(
            %{$ExpressionData},
        );

        # show attribute selection
        $Self->_AttributeSelection(
            %{$ExpressionData},
        );

        # show operator selection
        $Self->_OperatorSelection(
            %{$ExpressionData},
        );

        # TODO show dropdownfield or textfield (or date selection) for the caompare value

        #          'Selector' => '31',
        #          'ObjectID' => '1',
        #          'ExpressionID' => '94',
        #          'OperatorID' => '1',
        #          'ConditionID' => '184',
        #          'CompareValue' => 'DummyCompareValue1',
        #          'AttributeID' => '2'

    }

    return 1;
}

# show object dropdown field
sub _ObjectSelection {
    my ( $Self, %Param ) = @_;

    # get object list
    my $ObjectList = $Self->{ConditionObject}->ObjectList(
        UserID => $Self->{UserID},
    );

    # add an empty selection if no list is available or nothing is selected
    my $PossibleNone = 0;
    if ( !$ObjectList || !ref $ObjectList eq 'HASH' || !%{$ObjectList} || !$Param{ObjectID} ) {
        $PossibleNone = 1;
    }

    # generate ObjectOptionString
    my $ObjectOptionString = $Self->{LayoutObject}->BuildSelection(
        Data         => $ObjectList,
        Name         => 'ObjectID',
        SelectedID   => $Param{ObjectID},
        PossibleNone => $PossibleNone,
    );

    # output object selection
    $Self->{LayoutObject}->Block(
        Name => 'ExpressionOverviewRowElementObject',
        Data => {
            ObjectOptionString => $ObjectOptionString,
        },
    );

    return 1;
}

# show selector dropdown field
sub _SelectorSelection {
    my ( $Self, %Param ) = @_;

    # get selector list
    my $SelectorList = $Self->{ConditionObject}->ObjectSelectorList(
        ObjectID    => $Param{ObjectID},
        ConditionID => $Param{ConditionID},
        UserID      => $Self->{UserID},
    );

    # add an empty selection if no list is available or nothing is selected
    my $PossibleNone = 0;
    if ( !$SelectorList || !ref $SelectorList eq 'HASH' || !%{$SelectorList} || !$Param{Selector} )
    {
        $PossibleNone = 1;
    }

    # generate SelectorOptionString
    my $SelectorOptionString = $Self->{LayoutObject}->BuildSelection(
        Data         => $SelectorList,
        Name         => 'Selector',
        SelectedID   => $Param{Selector},
        PossibleNone => $PossibleNone,
    );

    # output selector selection
    $Self->{LayoutObject}->Block(
        Name => 'ExpressionOverviewRowElementSelector',
        Data => {
            SelectorOptionString => $SelectorOptionString,
        },
    );

    return 1;
}

# show attribute dropdown field
sub _AttributeSelection {
    my ( $Self, %Param ) = @_;

    # get attribute list
    my $AttributeList = $Self->{ConditionObject}->AttributeList(
        UserID => $Self->{UserID},
    );

    # TODO add code to check sysconfig for valid attributes for the given parameters

    # add an empty selection if no list is available or nothing is selected
    my $PossibleNone = 0;
    if (
        !$AttributeList
        || !ref $AttributeList eq 'HASH'
        || !%{$AttributeList}
        || !$Param{AttributeID}
        )
    {
        $PossibleNone = 1;
    }

    # generate AttributeOptionString
    my $AttributeOptionString = $Self->{LayoutObject}->BuildSelection(
        Data         => $AttributeList,
        Name         => 'AttributeID',
        SelectedID   => $Param{AttributeID},
        PossibleNone => $PossibleNone,
    );

    # output attribute selection
    $Self->{LayoutObject}->Block(
        Name => 'ExpressionOverviewRowElementAttribute',
        Data => {
            AttributeOptionString => $AttributeOptionString,
        },
    );

    return 1;
}

# show operator dropdown field
sub _OperatorSelection {
    my ( $Self, %Param ) = @_;

    # get operator list
    my $OperatorList = $Self->{ConditionObject}->OperatorList(
        UserID => $Self->{UserID},
    );

    # TODO add code to check sysconfig for valid operators for the given attribute

    # add an empty selection if no list is available or nothing is selected
    my $PossibleNone = 0;
    if (
        !$OperatorList
        || !ref $OperatorList eq 'HASH'
        || !%{$OperatorList}
        || !$Param{OperatorID}
        )
    {
        $PossibleNone = 1;
    }

    # generate OperatorOptionString
    my $OperatorOptionString = $Self->{LayoutObject}->BuildSelection(
        Data         => $OperatorList,
        Name         => 'OperatorID',
        SelectedID   => $Param{OperatorID},
        PossibleNone => $PossibleNone,
    );

    # output operator selection
    $Self->{LayoutObject}->Block(
        Name => 'ExpressionOverviewRowElementOperator',
        Data => {
            OperatorOptionString => $OperatorOptionString,
        },
    );

    return 1;
}

1;
