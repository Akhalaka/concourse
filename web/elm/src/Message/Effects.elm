port module Message.Effects exposing
    ( Effect(..)
    , ScrollDirection(..)
    , renderPipeline
    , renderSvgIcon
    , runEffect
    , stickyHeaderConfig
    , toHtmlID
    )

import Api
import Api.Endpoints as Endpoints
import Base64
import Browser.Dom exposing (Viewport, getViewport, getViewportOf, setViewportOf)
import Browser.Navigation as Navigation
import Concourse
import Concourse.BuildStatus exposing (BuildStatus)
import Concourse.Pagination exposing (Page)
import Json.Decode
import Json.Encode
import Maybe exposing (Maybe)
import Message.Callback exposing (Callback(..), TooltipPolicy(..))
import Message.Message
    exposing
        ( DomID(..)
        , VersionToggleAction(..)
        , VisibilityAction(..)
        )
import Process
import Routes
import Task
import Time
import Views.Styles


port renderPipeline : ( Json.Encode.Value, Json.Encode.Value ) -> Cmd msg


port pinTeamNames : StickyHeaderConfig -> Cmd msg


port tooltip : ( String, String ) -> Cmd msg


port tooltipHd : ( String, String ) -> Cmd msg


port resetPipelineFocus : () -> Cmd msg


port loadToken : () -> Cmd msg


port saveToken : String -> Cmd msg


port requestLoginRedirect : String -> Cmd msg


port openEventStream : { url : String, eventTypes : List String } -> Cmd msg


port closeEventStream : () -> Cmd msg


port checkIsVisible : String -> Cmd msg


port setFavicon : String -> Cmd msg


port rawHttpRequest : String -> Cmd msg


port renderSvgIcon : String -> Cmd msg


port loadSideBarState : () -> Cmd msg


port saveSideBarState : Bool -> Cmd msg


type alias StickyHeaderConfig =
    { pageHeaderHeight : Float
    , pageBodyClass : String
    , sectionHeaderClass : String
    , sectionClass : String
    , sectionBodyClass : String
    }


stickyHeaderConfig : StickyHeaderConfig
stickyHeaderConfig =
    { pageHeaderHeight = Views.Styles.pageHeaderHeight
    , pageBodyClass = "dashboard"
    , sectionClass = "dashboard-team-group"
    , sectionHeaderClass = "dashboard-team-header"
    , sectionBodyClass = "dashboard-team-pipelines"
    }


type Effect
    = FetchJob Concourse.JobIdentifier
    | FetchJobs Concourse.PipelineIdentifier
    | FetchJobBuilds Concourse.JobIdentifier (Maybe Page)
    | FetchResource Concourse.ResourceIdentifier
    | FetchCheck Int
    | FetchVersionedResources Concourse.ResourceIdentifier (Maybe Page)
    | FetchResources Concourse.PipelineIdentifier
    | FetchBuildResources Concourse.BuildId
    | FetchPipeline Concourse.PipelineIdentifier
    | FetchPipelines String
    | FetchClusterInfo
    | FetchInputTo Concourse.VersionedResourceIdentifier
    | FetchOutputOf Concourse.VersionedResourceIdentifier
    | FetchAllTeams
    | FetchUser
    | FetchBuild Float Int
    | FetchJobBuild Concourse.JobBuildIdentifier
    | FetchBuildJobDetails Concourse.JobIdentifier
    | FetchBuildHistory Concourse.JobIdentifier (Maybe Page)
    | FetchBuildPrep Float Int
    | FetchBuildPlan Concourse.BuildId
    | FetchBuildPlanAndResources Concourse.BuildId
    | FetchAllPipelines
    | FetchAllResources
    | FetchAllJobs
    | GetCurrentTime
    | GetCurrentTimeZone
    | DoTriggerBuild Concourse.JobIdentifier
    | RerunJobBuild Concourse.JobBuildIdentifier
    | DoAbortBuild Int
    | PauseJob Concourse.JobIdentifier
    | UnpauseJob Concourse.JobIdentifier
    | ResetPipelineFocus
    | RenderPipeline Json.Encode.Value Json.Encode.Value
    | RedirectToLogin
    | LoadExternal String
    | NavigateTo String
    | ModifyUrl String
    | DoPinVersion Concourse.VersionedResourceIdentifier
    | DoUnpinVersion Concourse.ResourceIdentifier
    | DoToggleVersion VersionToggleAction VersionId
    | DoCheck Concourse.ResourceIdentifier
    | SetPinComment Concourse.ResourceIdentifier String
    | SendTokenToFly String Int
    | SendTogglePipelineRequest Concourse.PipelineIdentifier Bool
    | ShowTooltip ( String, String )
    | ShowTooltipHd ( String, String )
    | SendOrderPipelinesRequest String (List String)
    | SendLogOutRequest
    | GetScreenSize
    | PinTeamNames StickyHeaderConfig
    | Scroll ScrollDirection String
    | SetFavIcon (Maybe BuildStatus)
    | SaveToken String
    | LoadToken
    | OpenBuildEventStream { url : String, eventTypes : List String }
    | CloseBuildEventStream
    | CheckIsVisible String
    | Focus String
    | Blur String
    | RenderSvgIcon String
    | ChangeVisibility VisibilityAction Concourse.PipelineIdentifier
    | LoadSideBarState
    | SaveSideBarState Bool
    | GetViewportOf DomID TooltipPolicy
    | GetElement DomID


type alias VersionId =
    Concourse.VersionedResourceIdentifier


type ScrollDirection
    = ToTop
    | Down
    | Up
    | ToBottom
    | Sideways Float
    | ToId String


runEffect : Effect -> Navigation.Key -> Concourse.CSRFToken -> Cmd Callback
runEffect effect key csrfToken =
    case effect of
        FetchJob id ->
            Api.get (Endpoints.Job id)
                |> Api.expectJson Concourse.decodeJob
                |> Api.request
                |> Task.attempt JobFetched

        FetchJobs id ->
            Api.get (Endpoints.Jobs id)
                |> Api.expectJson Json.Decode.value
                |> Api.request
                |> Task.attempt JobsFetched

        FetchJobBuilds id page ->
            Api.paginatedGet (Endpoints.JobBuilds id) page Concourse.decodeBuild
                |> Api.request
                |> Task.attempt JobBuildsFetched

        FetchResource id ->
            Api.get (Endpoints.Resource id)
                |> Api.expectJson Concourse.decodeResource
                |> Api.request
                |> Task.attempt ResourceFetched

        FetchCheck id ->
            Api.get (Endpoints.Check id)
                |> Api.expectJson Concourse.decodeCheck
                |> Api.request
                |> Task.attempt Checked

        FetchVersionedResources id paging ->
            Api.paginatedGet (Endpoints.ResourceVersions id)
                paging
                Concourse.decodeVersionedResource
                |> Api.request
                |> Task.map (\b -> ( paging, b ))
                |> Task.attempt VersionedResourcesFetched

        FetchResources id ->
            Api.get (Endpoints.Resources id)
                |> Api.expectJson Json.Decode.value
                |> Api.request
                |> Task.attempt ResourcesFetched

        FetchBuildResources id ->
            Api.get (Endpoints.BuildResources id)
                |> Api.expectJson Concourse.decodeBuildResources
                |> Api.request
                |> Task.map (\b -> ( id, b ))
                |> Task.attempt BuildResourcesFetched

        FetchPipeline id ->
            Api.get (Endpoints.Pipeline id)
                |> Api.expectJson Concourse.decodePipeline
                |> Api.request
                |> Task.attempt PipelineFetched

        FetchPipelines team ->
            Api.get (Endpoints.TeamPipelines team)
                |> Api.expectJson (Json.Decode.list Concourse.decodePipeline)
                |> Api.request
                |> Task.attempt PipelinesFetched

        FetchAllResources ->
            Api.get Endpoints.AllResources
                |> Api.expectJson
                    (Json.Decode.nullable <|
                        Json.Decode.list Concourse.decodeResource
                    )
                |> Api.request
                |> Task.map (Maybe.withDefault [])
                |> Task.attempt AllResourcesFetched

        FetchAllJobs ->
            Api.get Endpoints.AllJobs
                |> Api.expectJson
                    (Json.Decode.nullable <|
                        Json.Decode.list Concourse.decodeJob
                    )
                |> Api.request
                |> Task.map (Maybe.withDefault [])
                |> Task.attempt AllJobsFetched

        FetchClusterInfo ->
            Api.get Endpoints.ClusterInfo
                |> Api.expectJson Concourse.decodeInfo
                |> Api.request
                |> Task.attempt ClusterInfoFetched

        FetchInputTo id ->
            Api.get (Endpoints.ResourceVersionInputTo id)
                |> Api.expectJson (Json.Decode.list Concourse.decodeBuild)
                |> Api.request
                |> Task.map (\b -> ( id, b ))
                |> Task.attempt InputToFetched

        FetchOutputOf id ->
            Api.get (Endpoints.ResourceVersionOutputOf id)
                |> Api.expectJson (Json.Decode.list Concourse.decodeBuild)
                |> Api.request
                |> Task.map (\b -> ( id, b ))
                |> Task.attempt OutputOfFetched

        FetchAllTeams ->
            Api.get Endpoints.AllTeams
                |> Api.expectJson (Json.Decode.list Concourse.decodeTeam)
                |> Api.request
                |> Task.attempt AllTeamsFetched

        FetchAllPipelines ->
            Api.get Endpoints.AllPipelines
                |> Api.expectJson (Json.Decode.list Concourse.decodePipeline)
                |> Api.request
                |> Task.attempt AllPipelinesFetched

        GetCurrentTime ->
            Task.perform GotCurrentTime Time.now

        GetCurrentTimeZone ->
            Task.perform GotCurrentTimeZone Time.here

        DoTriggerBuild id ->
            Api.post (Endpoints.JobBuilds id) csrfToken
                |> Api.expectJson Concourse.decodeBuild
                |> Api.request
                |> Task.attempt BuildTriggered

        RerunJobBuild id ->
            Api.post (Endpoints.JobBuild id) csrfToken
                |> Api.expectJson Concourse.decodeBuild
                |> Api.request
                |> Task.attempt BuildTriggered

        PauseJob id ->
            Api.put (Endpoints.PauseJob id) csrfToken
                |> Api.request
                |> Task.attempt PausedToggled

        UnpauseJob id ->
            Api.put (Endpoints.UnpauseJob id) csrfToken
                |> Api.request
                |> Task.attempt PausedToggled

        RedirectToLogin ->
            requestLoginRedirect ""

        LoadExternal url ->
            Navigation.load url

        NavigateTo url ->
            Navigation.pushUrl key url

        ModifyUrl url ->
            Navigation.replaceUrl key url

        ResetPipelineFocus ->
            resetPipelineFocus ()

        RenderPipeline jobs resources ->
            renderPipeline ( jobs, resources )

        DoPinVersion id ->
            Api.put (Endpoints.PinResourceVersion id) csrfToken
                |> Api.request
                |> Task.attempt VersionPinned

        DoUnpinVersion id ->
            Api.put (Endpoints.UnpinResource id) csrfToken
                |> Api.request
                |> Task.attempt VersionUnpinned

        DoToggleVersion action id ->
            let
                endpoint =
                    case action of
                        Enable ->
                            Endpoints.EnableResourceVersion id

                        Disable ->
                            Endpoints.DisableResourceVersion id
            in
            Api.put endpoint csrfToken
                |> Api.request
                |> Task.attempt (VersionToggled action id)

        DoCheck rid ->
            Api.post (Endpoints.CheckResource rid) csrfToken
                |> Api.withJsonBody
                    (Json.Encode.object [ ( "from", Json.Encode.null ) ])
                |> Api.expectJson Concourse.decodeCheck
                |> Api.request
                |> Task.attempt Checked

        SetPinComment rid comment ->
            Api.put (Endpoints.PinResourceComment rid) csrfToken
                |> Api.withJsonBody
                    (Json.Encode.object
                        [ ( "pin_comment"
                          , Json.Encode.string comment
                          )
                        ]
                    )
                |> Api.request
                |> Task.attempt CommentSet

        SendTokenToFly authToken flyPort ->
            rawHttpRequest <| Routes.tokenToFlyRoute authToken flyPort

        SendTogglePipelineRequest id isPaused ->
            let
                endpoint =
                    if isPaused then
                        Endpoints.UnpausePipeline id

                    else
                        Endpoints.PausePipeline id
            in
            Api.put endpoint csrfToken
                |> Api.request
                |> Task.attempt (PipelineToggled id)

        ShowTooltip ( teamName, pipelineName ) ->
            tooltip ( teamName, pipelineName )

        ShowTooltipHd ( teamName, pipelineName ) ->
            tooltipHd ( teamName, pipelineName )

        SendOrderPipelinesRequest teamName pipelineNames ->
            Api.put (Endpoints.OrderTeamPipelines teamName) csrfToken
                |> Api.withJsonBody
                    (Json.Encode.list Json.Encode.string pipelineNames)
                |> Api.request
                |> Task.attempt (PipelinesOrdered teamName)

        SendLogOutRequest ->
            Api.get Endpoints.Logout
                |> Api.request
                |> Task.attempt LoggedOut

        GetScreenSize ->
            Task.perform ScreenResized getViewport

        PinTeamNames shc ->
            pinTeamNames shc

        FetchBuild delay buildId ->
            Process.sleep delay
                |> Task.andThen
                    (always
                        (Api.get (Endpoints.Build buildId)
                            |> Api.expectJson Concourse.decodeBuild
                            |> Api.request
                        )
                    )
                |> Task.attempt BuildFetched

        FetchJobBuild jbi ->
            Api.get (Endpoints.JobBuild jbi)
                |> Api.expectJson Concourse.decodeBuild
                |> Api.request
                |> Task.attempt BuildFetched

        FetchBuildJobDetails buildJob ->
            Api.get (Endpoints.Job buildJob)
                |> Api.expectJson Concourse.decodeJob
                |> Api.request
                |> Task.attempt BuildJobDetailsFetched

        FetchBuildHistory job page ->
            Api.paginatedGet (Endpoints.JobBuilds job) page Concourse.decodeBuild
                |> Api.request
                |> Task.attempt BuildHistoryFetched

        FetchBuildPrep delay buildId ->
            Process.sleep delay
                |> Task.andThen
                    (always
                        (Api.get (Endpoints.BuildPrep buildId)
                            |> Api.expectJson Concourse.decodeBuildPrep
                            |> Api.request
                        )
                    )
                |> Task.attempt (BuildPrepFetched buildId)

        FetchBuildPlanAndResources buildId ->
            Task.map2 (\a b -> ( a, b ))
                (Api.get (Endpoints.BuildPlan buildId)
                    |> Api.expectJson Concourse.decodeBuildPlan
                    |> Api.request
                )
                (Api.get (Endpoints.BuildResources buildId)
                    |> Api.expectJson Concourse.decodeBuildResources
                    |> Api.request
                )
                |> Task.attempt (PlanAndResourcesFetched buildId)

        FetchBuildPlan buildId ->
            Api.get (Endpoints.BuildPlan buildId)
                |> Api.expectJson Concourse.decodeBuildPlan
                |> Api.request
                |> Task.map (\p -> ( p, Concourse.emptyBuildResources ))
                |> Task.attempt (PlanAndResourcesFetched buildId)

        FetchUser ->
            Api.get Endpoints.UserInfo
                |> Api.expectJson Concourse.decodeUser
                |> Api.request
                |> Task.attempt UserFetched

        SetFavIcon status ->
            setFavicon (faviconName status)

        DoAbortBuild buildId ->
            Api.put (Endpoints.AbortBuild buildId) csrfToken
                |> Api.request
                |> Task.attempt BuildAborted

        Scroll ToTop id ->
            scroll id id (always 0) (always 0)

        Scroll Down id ->
            scroll id id (always 0) (.viewport >> .y >> (+) 60)

        Scroll Up id ->
            scroll id id (always 0) (.viewport >> .y >> (+) -60)

        Scroll ToBottom id ->
            scroll id id (always 0) (.scene >> .height)

        Scroll (Sideways delta) id ->
            scroll id id (.viewport >> .x >> (+) -delta) (always 0)

        Scroll (ToId id) idOfThingToScroll ->
            scroll id idOfThingToScroll (.viewport >> .x) (.viewport >> .y)

        SaveToken tokenValue ->
            saveToken tokenValue

        LoadToken ->
            loadToken ()

        Focus id ->
            Browser.Dom.focus id
                |> Task.attempt (always EmptyCallback)

        Blur id ->
            Browser.Dom.blur id
                |> Task.attempt (always EmptyCallback)

        OpenBuildEventStream config ->
            openEventStream config

        CloseBuildEventStream ->
            closeEventStream ()

        CheckIsVisible id ->
            checkIsVisible id

        RenderSvgIcon icon ->
            renderSvgIcon icon

        ChangeVisibility action pipelineId ->
            let
                endpoint =
                    case action of
                        Hide ->
                            Endpoints.HidePipeline pipelineId

                        Expose ->
                            Endpoints.ExposePipeline pipelineId
            in
            Api.put endpoint csrfToken
                |> Api.request
                |> Task.attempt (VisibilityChanged action pipelineId)

        LoadSideBarState ->
            loadSideBarState ()

        SaveSideBarState isOpen ->
            saveSideBarState isOpen

        GetViewportOf domID tooltipPolicy ->
            Browser.Dom.getViewportOf (toHtmlID domID)
                |> Task.attempt (GotViewport domID tooltipPolicy)

        GetElement domID ->
            Browser.Dom.getElement (toHtmlID domID)
                |> Task.attempt GotElement


toHtmlID : DomID -> String
toHtmlID domId =
    case domId of
        SideBarTeam t ->
            Base64.encode t

        SideBarPipeline p ->
            Base64.encode p.teamName ++ "_" ++ Base64.encode p.pipelineName

        FirstOccurrenceGetStepLabel stepID ->
            stepID ++ "_first_occurrence"

        StepState stepID ->
            stepID ++ "_state"

        Dashboard ->
            "dashboard"

        DashboardGroup teamName ->
            teamName

        _ ->
            ""


scroll :
    String
    -> String
    -> (Viewport -> Float)
    -> (Viewport -> Float)
    -> Cmd Callback
scroll srcId idOfThingToScroll getX getY =
    getViewportOf srcId
        |> Task.andThen
            (\info ->
                setViewportOf
                    idOfThingToScroll
                    (getX info)
                    (getY info)
            )
        |> Task.attempt (\_ -> EmptyCallback)


faviconName : Maybe BuildStatus -> String
faviconName status =
    case status of
        Just bs ->
            "/public/images/favicon-" ++ Concourse.BuildStatus.show bs ++ ".png"

        Nothing ->
            "/public/images/favicon.png"
