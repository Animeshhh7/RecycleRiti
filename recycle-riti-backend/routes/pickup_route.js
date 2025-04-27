const express = require('express');
const router = express.Router();
const pickupController = require('../controllers/pickup_controller');
const { authenticateJWT, restrictTo } = require('../middleware/auth');
const { PickupAssignment } = require('../models');

// Test route to verify the /pickup prefix
router.get('/test', (req, res) => {
  console.log('Test route accessed at /api/pickup/test');
  res.status(200).json({ success: true, message: 'Test route working' });
});

router.post('/schedule', authenticateJWT, pickupController.createPickupRequest);
router.get('/requests', authenticateJWT, pickupController.getPickupRequests);
router.get('/track/:id', authenticateJWT, pickupController.trackPickupRequest);
router.put('/cancel/:id', authenticateJWT, pickupController.cancelPickupRequest);
router.post('/assign/:id', authenticateJWT, restrictTo('admin', 'agent'), pickupController.pickupAssign);
router.put('/complete/:id', authenticateJWT, restrictTo('agent'), pickupController.completePickupRequest);

// DELETE endpoint to remove completed or cancelled pickup requests
router.delete('/requests/:id', authenticateJWT, async (req, res) => {
  try {
    const requestId = req.params.id;
    console.log(`Attempting to delete request: requestId=${requestId}, userId=${req.user.id}, role=${req.user.role}`);
    const pickupRequest = await pickupController.getPickupRequestById(requestId);

    if (!pickupRequest) {
      console.log(`Request not found: requestId=${requestId}`);
      return res.status(404).json({ success: false, message: 'Pickup request not found' });
    }

    // Allow deleting both completed and cancelled requests
    if (pickupRequest.status !== 'completed' && pickupRequest.status !== 'cancelled') {
      console.log(`Cannot delete request: requestId=${requestId}, status=${pickupRequest.status}`);
      return res.status(400).json({ success: false, message: 'Only completed or cancelled requests can be deleted' });
    }

    // Authorization logic
    let isAuthorized = false;

    // Allow admins to delete any request
    if (req.user.role === 'admin') {
      isAuthorized = true;
    }
    // Allow the user who created the request to delete it
    else if (req.user.id === pickupRequest.userId) {
      isAuthorized = true;
    }
    // Allow agents to delete completed or cancelled requests they are assigned to
    else if (req.user.role === 'agent') {
      const assignment = await PickupAssignment.findOne({
        where: {
          pickupRequestId: requestId,
          agentId: req.user.id,
        },
      });

      if (assignment) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      console.log(`User not authorized to delete request: requestId=${requestId}, userId=${req.user.id}, role=${req.user.role}`);
      return res.status(403).json({ success: false, message: 'Unauthorized to delete this request' });
    }

    await pickupController.deletePickupRequest(requestId);
    console.log(`Request deleted successfully: requestId=${requestId}, userRole=${req.user.role}`);
    res.status(200).json({ success: true, message: 'Pickup request deleted successfully' });
  } catch (error) {
    console.error('Error deleting pickup request:', error);
    res.status(500).json({ success: false, message: 'Server error while deleting pickup request' });
  }
});

module.exports = router;